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
    @center = record_support_center(@admin_root)

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
    support_public = provision_client(
      access_point: @root,
      actor: @support_user,
      role: :view,
      name: "Support public tickets #{SecureRandom.hex(4)}"
    )
    @support_public_client = support_public.fetch(:api_client)
    @support_public_token = support_public.fetch(:access_token)
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

  test "support team public client cannot show another customers ticket" do
    customer = User.create!(
      email: "ticket-customer-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = customer
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: customer,
      subject: "Customer crop #{SecureRandom.hex(4)}",
      body: "Please look at this field."
    )
    ticket_id = RecordingStudioSupport::Tickets.recording_for!(ticket).id
    Current.actor = nil

    assert RecordingStudioSupport::Messages.support_team_actor?(@support_user)
    refute RecordingStudioSupport::Messages.support_team_actor?(@support_public_client)

    get "#{PUBLIC_ROOT}/support_tickets/#{ticket_id}", headers: auth(@support_public_token), as: :json

    assert_response :not_found
  end

  test "public ticket index walks every own id once at limit 1" do
    own_ids = Array.new(3) { open_ticket_via_api! }
    stranger_id = open_ticket_via_api!(token: @stranger_token)

    seen = walk_ticket_ids(PUBLIC_ROOT, @patron_token)

    assert_equal own_ids.sort, seen.sort
    assert_equal own_ids.size, seen.size
    assert_equal seen.uniq, seen
    refute_includes seen, stranger_id
  end

  test "operations ticket index walks every current id once at limit 1" do
    patron_ids = Array.new(2) { open_ticket_via_api! }
    stranger_id = open_ticket_via_api!(token: @stranger_token)
    expected = RecordingStudioSupport::Tickets.ticket_recordings.where(
      recordable_id: RecordingStudioSupport::Tickets.current.select(:id)
    ).pluck(:id)

    seen = walk_ticket_ids(OPERATIONS_ROOT, @editor_operations_token)

    assert_includes expected, stranger_id
    patron_ids.each { |id| assert_includes expected, id }
    assert_equal expected.sort, seen.sort
    assert_equal expected.size, seen.size
    assert_equal seen.uniq, seen
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

  def open_ticket_via_api!(token: @patron_token)
    post "#{PUBLIC_ROOT}/support_tickets",
         headers: auth(token),
         params: { subject: "Ticket #{SecureRandom.hex(4)}", body: "Please take a look." },
         as: :json

    assert_response :created
    response.parsed_body.fetch("id")
  end

  def walk_ticket_ids(root, token)
    seen = []
    pagination_token = nil
    pages = 0

    loop do
      pages += 1
      assert_operator pages, :<, 50, "ticket index pagination did not end"
      params = { limit: 1 }
      params[:pagination_token] = pagination_token if pagination_token.present?
      get "#{root}/support_tickets", headers: auth(token), params: params, as: :json

      assert_response :success
      body = response.parsed_body
      records = body.fetch("records")
      meta = body.fetch("meta")
      records.each { |record| seen << record.fetch("id") }
      break unless truthy_meta?(meta, "has_more")

      pagination_token = meta["next_pagination_token"] || meta[:next_pagination_token]
      assert pagination_token.present?, "expected next_pagination_token when has_more"
    end

    seen
  end

  def truthy_meta?(meta, key)
    value = meta[key] || meta[key.to_sym]
    value == true || value == "true"
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
