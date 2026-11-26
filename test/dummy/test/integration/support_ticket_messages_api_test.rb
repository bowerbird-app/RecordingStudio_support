# frozen_string_literal: true

require "test_helper"

class SupportTicketMessagesApiTest < ActionDispatch::IntegrationTest
  PUBLIC_ROOT = "/recording_studio_api/api/v1"
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"

  setup do
    @support_user = User.create!(
      email: "ticket-messages-support-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @support_user
    @workspace = Workspace.create!(name: "Ticket messages #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: @support_user)
    @admin_root = RecordingStudio.create_root_recording!(AdminRoot.find_or_create_by!(name: "Admin"), actor: @support_user)
    grant!(@admin_root, @support_user, :admin)
    bootstrap_owner!(@root, @support_user)
    @center = record_support_center(@admin_root)

    @patron_token = provision_token(
      access_point: @root,
      actor: @support_user,
      role: :view,
      name: "Patron messages #{SecureRandom.hex(4)}"
    )
    @other_user = create_support_user!(
      email: "ticket-messages-other-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Other",
      last_name: "Person",
      time_zone: "UTC"
    )
    grant!(@root, @other_user, :admin)
    @stranger_token = provision_token(
      access_point: @root,
      actor: @other_user,
      role: :view,
      name: "Other person messages #{SecureRandom.hex(4)}"
    )
    @editor_operations_token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :edit,
      name: "Message operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    @viewer_operations_token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :view,
      name: "Message viewer operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "public lists replies marks read and counts unread" do
    ticket_id = open_ticket_via_api!
    get "#{PUBLIC_ROOT}/support_ticket_messages/#{ticket_id}", headers: auth(@patron_token), as: :json

    assert_response :success
    bodies = response.parsed_body.fetch("records").map { |record| record.fetch("body") }
    assert_equal ["Please take a look."], bodies

    post "#{PUBLIC_ROOT}/support_ticket_reply/#{ticket_id}",
         headers: auth(@patron_token),
         params: { body: "Still stuck on export." },
         as: :json

    assert_response :success
    assert_equal "Still stuck on export.", response.parsed_body.fetch("body")

    post "#{PUBLIC_ROOT}/support_ticket_mark_read/#{ticket_id}",
         headers: auth(@patron_token),
         as: :json

    assert_response :success
    assert_equal ticket_id, response.parsed_body.fetch("id")

    get "#{PUBLIC_ROOT}/support_ticket_unread_count", headers: auth(@patron_token), as: :json

    assert_response :success
    assert_equal 0, response.parsed_body.fetch("unread_count")
  end

  test "requester reply reopens a resolved ticket when the host write policy refuses the customer" do
    ticket_id = open_ticket_via_api!

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { status: "resolved" },
          as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")

    with_strict_write_policy do
      post "#{PUBLIC_ROOT}/support_ticket_reply/#{ticket_id}",
           headers: auth(@patron_token),
           params: { body: "It broke again." },
           as: :json
    end

    assert_response :success

    get "#{PUBLIC_ROOT}/support_tickets/#{ticket_id}", headers: auth(@patron_token), as: :json

    assert_response :success
    assert_equal "open", response.parsed_body.fetch("status")
    assert_nil response.parsed_body["resolved_at"]
  end

  test "requester reply reopens a resolved ticket" do
    ticket_id = open_ticket_via_api!

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { status: "resolved" },
          as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")

    post "#{PUBLIC_ROOT}/support_ticket_reply/#{ticket_id}",
         headers: auth(@patron_token),
         params: { body: "It broke again." },
         as: :json

    assert_response :success

    get "#{PUBLIC_ROOT}/support_tickets/#{ticket_id}", headers: auth(@patron_token), as: :json

    assert_response :success
    assert_equal "open", response.parsed_body.fetch("status")
    assert_nil response.parsed_body["resolved_at"]
  end

  test "operations lists messages and counts unread" do
    ticket_id = open_ticket_via_api!

    get "#{OPERATIONS_ROOT}/support_ticket_messages/#{ticket_id}",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success
    bodies = response.parsed_body.fetch("records").map { |record| record.fetch("body") }
    assert_equal ["Please take a look."], bodies

    get "#{OPERATIONS_ROOT}/support_ticket_unread_count",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success
    unread_before_read = response.parsed_body.fetch("unread_count")
    assert_kind_of Integer, unread_before_read
    assert_operator unread_before_read, :>=, 1

    post "#{OPERATIONS_ROOT}/support_ticket_mark_read/#{ticket_id}",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success

    get "#{OPERATIONS_ROOT}/support_ticket_unread_count",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success
    assert_equal unread_before_read - 1, response.parsed_body.fetch("unread_count")
  end

  test "staff reply does not reopen a resolved ticket" do
    ticket_id = open_ticket_via_api!

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { status: "resolved" },
          as: :json

    assert_response :success

    post "#{OPERATIONS_ROOT}/support_ticket_reply/#{ticket_id}",
         headers: auth(@editor_operations_token),
         params: { body: "Closing note from staff." },
         as: :json

    assert_response :success

    get "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")
  end

  test "another signed in person cannot reply or mark a ticket read" do
    ticket_id = open_ticket_via_api!

    get "#{PUBLIC_ROOT}/support_ticket_messages/#{ticket_id}", headers: auth(@stranger_token), as: :json

    assert_response :not_found

    post "#{PUBLIC_ROOT}/support_ticket_reply/#{ticket_id}",
         headers: auth(@stranger_token),
         params: { body: "Not my ticket." },
         as: :json

    assert_response :not_found

    post "#{PUBLIC_ROOT}/support_ticket_mark_read/#{ticket_id}",
         headers: auth(@stranger_token),
         as: :json

    assert_response :not_found
  end

  test "staff can mark a ticket read" do
    ticket_id = open_ticket_via_api!

    post "#{OPERATIONS_ROOT}/support_ticket_mark_read/#{ticket_id}",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success
    assert_equal ticket_id, response.parsed_body.fetch("id")
  end

  test "anonymous cannot reply or mark a ticket read" do
    ticket_id = open_ticket_via_api!

    post "#{PUBLIC_ROOT}/support_ticket_reply/#{ticket_id}",
         params: { body: "No token." },
         as: :json

    assert_response :unauthorized

    post "#{PUBLIC_ROOT}/support_ticket_mark_read/#{ticket_id}", as: :json

    assert_response :unauthorized
  end

  test "operations viewer can list ticket messages and cannot reply" do
    ticket_id = open_ticket_via_api!

    get "#{OPERATIONS_ROOT}/support_ticket_messages/#{ticket_id}",
        headers: auth(@viewer_operations_token),
        as: :json

    assert_response :success
    bodies = response.parsed_body.fetch("records").map { |record| record.fetch("body") }
    assert_equal ["Please take a look."], bodies

    get "#{OPERATIONS_ROOT}/support_ticket_unread_count",
        headers: auth(@viewer_operations_token),
        as: :json

    assert_response :success
    assert_operator response.parsed_body.fetch("unread_count"), :>=, 0

    post "#{OPERATIONS_ROOT}/support_ticket_reply/#{ticket_id}",
         headers: auth(@viewer_operations_token),
         params: { body: "Viewer should not reply." },
         as: :json

    assert_response :forbidden
  end

  test "missing token is unauthorized on ticket messages" do
    get "#{PUBLIC_ROOT}/support_ticket_unread_count", as: :json

    assert_response :unauthorized
  end

  test "message endpoints register on public and operations" do
    %i[public operations].each do |api|
      RecordingStudioSupport::Api::TicketMessages::NAMES.each do |name|
        endpoint = RecordingStudioApi.registered_endpoint(name, api: api)
        assert endpoint, "#{name} missing on #{api}"
        assert_equal ["Support Messages"], endpoint.openapi_tags
        endpoint.validate!
      end
    end
  end

  test "scope_id false writes declare required_role" do
    unscoped_writes = []

    %i[public operations].each do |api|
      RecordingStudioApi.api(api).registered_endpoint_registry.all.each do |endpoint|
        next unless endpoint.handler.to_s.start_with?("RecordingStudioSupport::")
        next unless endpoint.instance_variable_get(:@scope_id) == false
        next if endpoint.http_verb == :get

        endpoint.validate!
        assert_equal :view, endpoint.required_role, endpoint.name
        unscoped_writes << endpoint.name
      end
    end

    assert_equal %w[mark_support_ticket_read reply_to_support_ticket], unscoped_writes.sort
  end

  private

  def open_ticket_via_api!(token: @patron_token)
    post "#{PUBLIC_ROOT}/support_tickets",
         headers: auth(token),
         params: { subject: "Ticket #{SecureRandom.hex(4)}", body: "Please take a look." },
         as: :json

    assert_response :created
    response.parsed_body.fetch("id")
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, admin_root_recording: nil, admin_root_role: :edit, api: :public)
    provision_client(
      access_point: access_point,
      actor: actor,
      role: role,
      name: name,
      admin_root_recording: admin_root_recording,
      admin_root_role: admin_root_role,
      api: api
    ).fetch(:access_token)
  end

  def provision_client(access_point:, actor:, role:, name:, admin_root_recording: nil, admin_root_role: :edit, api: :public)
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

    payload.merge(access_token: token_result.value.fetch(:access_token))
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
