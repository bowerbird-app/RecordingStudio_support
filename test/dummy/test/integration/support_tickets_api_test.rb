# frozen_string_literal: true

require "test_helper"

class SupportTicketsApiTest < ActionDispatch::IntegrationTest
  PUBLIC_ROOT = "/recording_studio_api/api/v1"
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"

  setup do
    @support_user = User.create!(
      email: "ticket-api-support-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @support_user
    @workspace = Workspace.create!(name: "Ticket API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant!(@admin_root, @support_user, :admin)
    bootstrap_owner!(@root, @support_user)
    record_support_center(@admin_root)

    @patron_token = provision_token(
      access_point: @root,
      actor: @support_user,
      role: :view,
      name: "Patron tickets #{SecureRandom.hex(4)}"
    )
    @stranger_token = provision_token(
      access_point: @root,
      actor: @support_user,
      role: :view,
      name: "Stranger tickets #{SecureRandom.hex(4)}"
    )
    @editor_operations_token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :edit,
      name: "Ticket operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    @viewer_operations_token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :view,
      name: "Ticket viewer operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "ticket success opens lists shows and updates" do
    subject = "Quiet crop #{SecureRandom.hex(4)}"

    post "#{PUBLIC_ROOT}/support_tickets",
         headers: auth(@patron_token),
         params: { subject: subject, body: "The quieter crop is stuck.", priority: "high" },
         as: :json

    assert_response :created
    created = response.parsed_body
    ticket_id = created.fetch("id")
    assert_equal subject, created.fetch("subject")
    assert_equal "high", created.fetch("priority")
    assert_equal "open", created.fetch("status")

    get "#{PUBLIC_ROOT}/support_tickets", headers: auth(@patron_token), as: :json

    assert_response :success
    ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    assert_includes ids, ticket_id

    get "#{PUBLIC_ROOT}/support_tickets/#{ticket_id}", headers: auth(@patron_token), as: :json

    assert_response :success
    assert_equal subject, response.parsed_body.fetch("subject")

    get "#{OPERATIONS_ROOT}/support_tickets", headers: auth(@editor_operations_token), as: :json

    assert_response :success
    assert_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, ticket_id

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { status: "resolved", priority: "low" },
          as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")
    assert_equal "low", response.parsed_body.fetch("priority")
    assert_not_nil response.parsed_body["resolved_at"]
  end

  test "missing token is unauthorized on tickets" do
    get "#{PUBLIC_ROOT}/support_tickets", as: :json

    assert_response :unauthorized

    post "#{PUBLIC_ROOT}/support_tickets",
         params: { subject: "No token", body: "Hi" },
         as: :json

    assert_response :unauthorized
  end

  test "operations viewer is forbidden below support team edit" do
    ticket_id = open_ticket_via_api!

    get "#{OPERATIONS_ROOT}/support_tickets", headers: auth(@viewer_operations_token), as: :json

    assert_response :forbidden

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@viewer_operations_token),
          params: { status: "resolved" },
          as: :json

    assert_response :forbidden
  end

  test "another users ticket is not found" do
    ticket_id = open_ticket_via_api!

    get "#{PUBLIC_ROOT}/support_tickets/#{ticket_id}", headers: auth(@stranger_token), as: :json

    assert_response :not_found
  end

  test "invalid status or priority is unprocessable" do
    ticket_id = open_ticket_via_api!

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { status: "waiting_on_customer" },
          as: :json

    assert_response :unprocessable_entity

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { priority: "urgent" },
          as: :json

    assert_response :unprocessable_entity
  end

  test "ticket openapi titles are type first" do
    public_ticket = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioSupport::SupportTicket",
      api: :public
    )
    operations_ticket = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioSupport::SupportTicket",
      api: :operations
    )

    assert_equal %i[create index show], public_ticket.operations
    assert_equal %i[index show update], operations_ticket.operations
    assert_equal "Ticket - Open", public_ticket.openapi.dig(:create, :title)
    assert_equal "Ticket - Update", operations_ticket.openapi.dig(:update, :title)
    assert_equal "Ticket - Index", public_ticket.openapi.dig(:index, :title)
    assert_equal "Ticket - Show", operations_ticket.openapi.dig(:show, :title)
    assert_equal ["Support"], public_ticket.openapi.fetch(:tags)
  end

  private

  def open_ticket_via_api!
    post "#{PUBLIC_ROOT}/support_tickets",
         headers: auth(@patron_token),
         params: { subject: "Ticket #{SecureRandom.hex(4)}", body: "Please take a look." },
         as: :json

    assert_response :created
    response.parsed_body.fetch("id")
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, admin_root_recording: nil, admin_root_role: :edit, api: :public)
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name,
      api: api
    )
    raise result.error unless result.success?

    payload = result.value
    grant!(admin_root_recording, payload.fetch(:api_client), admin_root_role) if admin_root_recording

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
    return if result.success? || already_granted?(result)

    raise result.error
  end

  def grant!(recording, actor, role)
    grant_role!(recording, actor, role)
  end
end
