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
        params: { interval: "month" },
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

  test "operations staff token reads support queue metrics" do
    open_tickets = RecordingStudioSupport::SupportTicket.open
    get "#{OPERATIONS_ROOT}/metrics/support_tickets/unassigned_open",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal open_tickets.where(assignee_id: nil).count, response.parsed_body.fetch("value")
    assert_equal "count", response.parsed_body.fetch("unit")
    assert_operator response.parsed_body.fetch("value"), :>=, 1
    assert_operator response.parsed_body.fetch("value"), :<, open_tickets.count

    travel_to Time.utc(2026, 4, 1, 12) do
      get "#{OPERATIONS_ROOT}/metrics/support_tickets/oldest_open_age",
          headers: auth(@staff_operations_token),
          as: :json
      assert_response :success
      expected = (Time.current - open_tickets.minimum(:created_at)).to_i
      assert_equal expected, response.parsed_body.fetch("value")
      assert_equal "seconds", response.parsed_body.fetch("unit")
      assert_operator response.parsed_body.fetch("value"), :>=, (Time.current - Time.utc(2026, 2, 10, 12)).to_i
    end
  end

  test "oldest open age has no value and unassigned open is zero without open tickets" do
    RecordingStudioSupport::SupportTicket.open.find_each { |ticket| ticket.update!(status: :resolved) }

    get "#{OPERATIONS_ROOT}/metrics/support_tickets/oldest_open_age",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal "seconds", response.parsed_body.fetch("unit")
    refute response.parsed_body.key?("value"), "no open tickets means no age value"

    get "#{OPERATIONS_ROOT}/metrics/support_tickets/unassigned_open",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal 0, response.parsed_body.fetch("value")
  end

  test "open and unassigned open group by priority and fold small groups into other" do
    seed_high_priority_queue!

    %w[open unassigned_open].each do |name|
      get "#{OPERATIONS_ROOT}/metrics/support_tickets/#{name}",
          params: { group_by: "priority" },
          headers: auth(@staff_operations_token),
          as: :json
      assert_response :success
      body = response.parsed_body
      relation = RecordingStudioSupport::SupportTicket.open
      relation = relation.where(assignee_id: nil) if name == "unassigned_open"
      counts = relation.group(:priority).count

      assert_equal "priority", body.fetch("group_by")
      assert_equal relation.count, body.fetch("value")
      groups = body.fetch("groups").to_h { |row| [row.fetch("key"), row.fetch("value")] }
      assert_equal counts["high"], groups["high"]
      counts.each { |key, count| assert_not groups.key?(key) if count < 5 }
      assert_equal body.fetch("value"), groups.values.sum + body.dig("other", "value").to_i
      small = counts.values.select { |count| count < 5 }
      assert_equal small.sum, body.dig("other", "value").to_i
      assert_operator small.size, :>=, 1
    end
  end

  test "opened time series groups by status and priority with other fold" do
    seed_high_priority_queue!

    %w[status priority].each do |field|
      get "#{OPERATIONS_ROOT}/metrics/support_tickets/opened",
          params: { interval: "month", group_by: field, from: "2026-02-01", to: "2026-04-01" },
          headers: auth(@staff_operations_token),
          as: :json
      assert_response :success
      body = response.parsed_body
      assert_equal field, body.fetch("group_by")
      totals = timeseries_counts(body)
      kept = body.fetch("groups").map { |row| row.fetch("key") }
      other = body.fetch("other")
      assert other.present?, "groups below min_group_size fold into other for #{field}"
      totals.each do |date, total|
        grouped = body.fetch("groups").sum { |row| series_value(row.fetch("data"), date) }
        assert_equal total, grouped + series_value(other.fetch("data"), date)
      end
      window = RecordingStudioSupport::SupportTicket.where(created_at: Time.utc(2026, 2, 1)...Time.utc(2026, 4, 1))
      window.group(field).count.each do |key, count|
        count >= 5 ? assert_includes(kept, key) : refute_includes(kept, key)
      end
    end
  end

  test "group_by rejects unsupported and non-groupable metrics" do
    get "#{OPERATIONS_ROOT}/metrics/support_tickets/open",
        params: { group_by: "assignee_id" },
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :unprocessable_entity

    get "#{OPERATIONS_ROOT}/metrics/support_tickets/oldest_open_age",
        params: { group_by: "priority" },
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :unprocessable_entity
  end

  test "catalog lists group_by, date range and freshness for ticket metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json
    assert_response :success
    catalog = response.parsed_body.fetch("metrics").index_by { |row| row.fetch("identifier") }

    assert_equal %w[priority], catalog.dig("support_tickets.open", "group_by")
    assert_equal %w[priority], catalog.dig("support_tickets.unassigned_open", "group_by")
    assert_equal %w[status priority], catalog.dig("support_tickets.opened", "group_by")
    assert_equal [], catalog.dig("support_tickets.oldest_open_age", "group_by")
    assert_equal [], catalog.dig("support_tickets.by_status", "group_by")
    assert_equal 5, catalog.dig("support_tickets.open", "min_group_size")
    assert_equal "seconds", catalog.dig("support_tickets.oldest_open_age", "unit")
    assert_equal true, catalog.dig("support_tickets.opened", "date_range", "supported")
    assert_equal false, catalog.dig("support_tickets.open", "date_range", "supported")
    catalog.each_value do |entry|
      next unless entry.fetch("identifier").start_with?("support_tickets.")

      assert entry.key?("timezone")
      assert entry.key?("freshness")
    end
  end

  test "metrics index lists support ticket and page metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    %w[
      support_tickets.open
      support_tickets.unassigned_open
      support_tickets.oldest_open_age
      support_tickets.by_status
      support_tickets.by_priority
      support_tickets.opened
      support_pages.total
    ].each { |identifier| assert_includes identifiers, identifier }
  end

  test "non-admin operations token is denied support metrics" do
    %w[unassigned_open oldest_open_age].each do |name|
      get "#{OPERATIONS_ROOT}/metrics/support_tickets/#{name}",
          headers: auth(@workspace_operations_token),
          as: :json
      assert_response :forbidden
    end

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
    refute_includes identifiers, "support_tickets.unassigned_open"
    refute_includes identifiers, "support_tickets.oldest_open_age"
    refute_includes identifiers, "support_pages.total"
  end

  test "public API token is denied operations support metrics" do
    get "#{OPERATIONS_ROOT}/metrics/support_tickets/oldest_open_age",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

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
      assigned = RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "March assigned #{SecureRandom.hex(4)}",
        body: "On it.",
        priority: :normal
      )
      assigned.update!(assignee: @staff)
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

  def seed_high_priority_queue!
    travel_to Time.utc(2026, 3, 20, 12) do
      5.times do |index|
        RecordingStudioSupport::Tickets.open!(
          actor: @patron,
          subject: "Queue high #{index} #{SecureRandom.hex(4)}",
          body: "Urgent.",
          priority: :high
        )
      end
      RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "Queue low #{SecureRandom.hex(4)}",
        body: "Whenever.",
        priority: :low
      )
    end
  end

  def series_value(rows, date)
    rows.find { |row| row.fetch("date").to_s == date }&.fetch("value").to_i
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
