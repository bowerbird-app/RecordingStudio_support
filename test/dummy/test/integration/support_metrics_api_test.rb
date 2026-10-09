# frozen_string_literal: true

require "test_helper"

class SupportMetricsApiTest < ActionDispatch::IntegrationTest
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"
  PUBLIC_ROOT = "/recording_studio_api/api/v1"

  setup do
    @staff = User.create!(
      email: "metrics-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @patron = User.create!(
      email: "metrics-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @staff
    @workspace = Workspace.create!(name: "Metrics #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner!(@root, @staff)
    grant!(@root, @patron, :edit)

    seed_tickets!
    seed_pages!

    @staff_operations_token = provision_token(
      access_point: @admin_root,
      actor: @staff,
      role: :edit,
      name: "Staff operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_operations_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Workspace operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @public_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :view,
      name: "Public metrics #{SecureRandom.hex(4)}"
    )
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "operations staff token reads support ticket and page metrics" do
    get "#{OPERATIONS_ROOT}/metrics/support_tickets/open",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal RecordingStudioSupport::SupportTicket.open.count, response.parsed_body.fetch("value")

    get "#{OPERATIONS_ROOT}/metrics/support_tickets/by_status",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    status_counts = breakdown_counts(response.parsed_body)
    RecordingStudioSupport::SupportTicket::STATUSES.each do |status|
      assert_equal RecordingStudioSupport::SupportTicket.where(status: status).count, status_counts[status].to_i
    end

    get "#{OPERATIONS_ROOT}/metrics/support_tickets/by_priority",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    priority_counts = breakdown_counts(response.parsed_body)
    RecordingStudioSupport::SupportTicket::PRIORITIES.each do |priority|
      assert_equal RecordingStudioSupport::SupportTicket.where(priority: priority).count, priority_counts[priority].to_i
    end

    get "#{OPERATIONS_ROOT}/metrics/support_tickets/opened",
        params: { interval: "month", start: "2026-02-01T00:00:00Z", end: "2026-04-01T00:00:00Z" },
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    opened = timeseries_counts(response.parsed_body)
    assert_equal tickets_opened_between(Time.utc(2026, 2, 1), Time.utc(2026, 3, 1)), opened["2026-02-01"]
    assert_equal tickets_opened_between(Time.utc(2026, 3, 1), Time.utc(2026, 4, 1)), opened["2026-03-01"]
    assert_operator opened["2026-02-01"], :>=, 1
    assert_operator opened["2026-03-01"], :>=, 2

    live_pages = RecordingStudioSupport::Admin::Queries.kept_page_recordings.count
    get "#{OPERATIONS_ROOT}/metrics/support_pages/total",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal live_pages, response.parsed_body.fetch("value")
    assert_operator RecordingStudioSupport::SupportPage.count, :>, live_pages
  end

  test "metrics index lists support ticket and page metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    %w[
      support_tickets.open
      support_tickets.by_status
      support_tickets.by_priority
      support_tickets.opened
      support_pages.total
    ].each { |identifier| assert_includes identifiers, identifier }
  end

  test "non-admin operations token is denied support metrics" do
    get "#{OPERATIONS_ROOT}/metrics/support_tickets/open",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics/support_pages/total",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@workspace_operations_token), as: :json
    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    refute_includes identifiers, "support_tickets.open"
    refute_includes identifiers, "support_pages.total"
  end

  test "public API token is denied operations support metrics" do
    get "#{OPERATIONS_ROOT}/metrics/support_tickets/open",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

    get "#{OPERATIONS_ROOT}/metrics/support_pages/total",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

    get "#{PUBLIC_ROOT}/metrics/support_pages/total",
        headers: auth(@public_token),
        as: :json
    assert_includes [404, 401, 403], response.status
  end

  private

  def seed_tickets!
    travel_to Time.utc(2026, 2, 10, 12) do
      RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "February open #{SecureRandom.hex(4)}",
        body: "Still broken.",
        priority: :high
      )
    end
    travel_to Time.utc(2026, 3, 12, 12) do
      waiting = RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "March waiting #{SecureRandom.hex(4)}",
        body: "Need a reply.",
        priority: :low
      )
      waiting.update!(status: :waiting_on_customer)
      resolved = RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "March resolved #{SecureRandom.hex(4)}",
        body: "Fixed.",
        priority: :normal
      )
      resolved.update!(status: :resolved)
    end
  end

  def seed_pages!
    section = record_support_section(@root, title: "Metrics section #{SecureRandom.hex(4)}")
    live = record_support_page(@root, section, title: "Live metrics page #{SecureRandom.hex(4)}")
    edited = record_support_page(@root, section, title: "Edited metrics page #{SecureRandom.hex(4)}")
    trashed = record_support_page(@root, section, title: "Trashed metrics page #{SecureRandom.hex(4)}")

    RecordingStudioSupport::Pages.revise!(
      recording: edited,
      title: "#{edited.recordable.title} v2",
      body: "Second snapshot",
      actor: @staff
    )
    RecordingStudioSupport::Pages.revise!(
      recording: edited,
      title: "#{edited.recordable.title} v3",
      body: "Third snapshot",
      actor: @staff
    )
    RecordingStudioSupport::Pages.trash!(recording: trashed, actor: @staff)

    @live_page = live
  end

  def breakdown_counts(payload)
    payload.fetch("data").to_h { |row| [row.fetch("key").to_s, row.fetch("value")] }
  end

  def tickets_opened_between(start_at, end_at)
    RecordingStudioSupport::SupportTicket.where(created_at: start_at...end_at).count
  end

  def timeseries_counts(payload)
    payload.fetch("data").to_h { |row| [row.fetch("date").to_s, row.fetch("value")] }
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, api: :public)
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name,
      api: api
    )
    raise result.error unless result.success?

    payload = result.value
    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token),
      api: api
    )
    raise token_result.error unless token_result.success?

    token_result.value.fetch(:access_token)
  end

  def bootstrap_owner!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: recording,
      actor: actor
    )
    raise result.error if result.failure?
  end

  def grant!(recording, actor, role)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
