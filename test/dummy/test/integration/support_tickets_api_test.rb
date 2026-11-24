# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

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
    @root = RecordingStudio.create_root_recording!(@workspace, actor: @support_user)
    @admin_root = RecordingStudio.create_root_recording!(AdminRoot.find_or_create_by!(name: "Admin"), actor: @support_user)
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

  test "open accepts subject and body and rejects a missing body" do
    post "#{PUBLIC_ROOT}/support_tickets",
         headers: auth(@patron_token),
         params: { subject: "Crop note #{SecureRandom.hex(4)}", body: "The gate sticks." },
         as: :json

    assert_response :created
    assert_equal "open", response.parsed_body.fetch("status")

    before = RecordingStudioSupport::SupportTicket.count
    post "#{PUBLIC_ROOT}/support_tickets",
         headers: auth(@patron_token),
         params: { subject: "No message #{SecureRandom.hex(4)}" },
         as: :json

    assert_response :unprocessable_entity
    assert_equal before, RecordingStudioSupport::SupportTicket.count
  end

  test "open support ticket mcp input matches the open body" do
    tools = []
    recorder = Module.new
    recorder.define_singleton_method(:register_tool) { |**kwargs| tools << kwargs }
    recorder.define_singleton_method(:register_type) { |**| }
    Object.const_set(:RecordingStudioMcp, recorder)
    RecordingStudioSupport::McpCopy.register!

    tool = tools.find { |entry| entry.fetch(:name) == "open_support_ticket" }
    schema = RecordingStudioSupport::Api::TicketOpenapi.open_body.dig(:content, "application/json", :schema)
    input = tool.fetch(:input)
    required = schema.fetch(:required)
    priorities = RecordingStudioSupport::SupportTicket::PRIORITIES

    assert_equal %w[subject body priority], schema.fetch(:properties).keys.map(&:to_s)
    refute schema.fetch(:properties).key?(:parent_id)
    refute schema.fetch(:properties).key?("parent_id")
    assert_equal %w[subject body], required
    assert_equal required, input.select { |_name, meta| meta.fetch(:required) }.keys
    assert_equal priorities, schema.dig(:properties, :priority, :enum)
    assert_equal priorities, input.dig("priority", :enum)
    refute input.fetch("priority").fetch(:required)
    assert input.dig("subject", :required)
    assert input.dig("body", :required)
    assert_equal "string", input.dig("body", :type)
    assert_includes tool.fetch(:description), priorities.join(", ")
    assert_includes tool.fetch(:description), "Leave parent_id blank"
    refute input.key?("parent_id")

    close = tools.find { |entry| entry.fetch(:name) == "close_support_ticket" }
    assert_equal :close_support_ticket, close.fetch(:endpoint)
    assert_equal ["id"], close.fetch(:input).keys
    refute_includes RecordingStudioSupport::McpCopy.tool_names(api: :public), "close_support_ticket"
    assert_nil RecordingStudioApi.registered_endpoint(:close_support_ticket, api: :public)
    assert RecordingStudioApi.registered_endpoint(:close_support_ticket, api: :operations)
  ensure
    Object.send(:remove_const, :RecordingStudioMcp) if Object.const_defined?(:RecordingStudioMcp, false)
  end

  test "staff can close a ticket and closing again changes nothing" do
    ticket_id = open_ticket_via_api!

    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")
    resolved_at = response.parsed_body.fetch("resolved_at")
    assert resolved_at.present?

    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")
    assert_equal resolved_at, response.parsed_body.fetch("resolved_at")
  end

  test "close then a requester reply reopens the ticket" do
    ticket_id = open_ticket_via_api!
    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success

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

  test "ticket owner who is not staff cannot close" do
    ticket_id = open_ticket_via_api!

    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@patron_token),
         as: :json

    assert_includes [401, 403], response.status
    assert_equal "open", ticket_status(ticket_id)
  end

  test "anonymous cannot close a ticket" do
    ticket_id = open_ticket_via_api!

    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}", as: :json

    assert_response :unauthorized
    assert_equal "open", ticket_status(ticket_id)
  end

  test "another signed in non staff user cannot close" do
    ticket_id = open_ticket_via_api!

    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@stranger_token),
         as: :json

    assert_includes [401, 403], response.status

    post "#{OPERATIONS_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@viewer_operations_token),
         as: :json

    assert_response :forbidden
    assert_equal "open", ticket_status(ticket_id)
  end

  test "public server does not register close support ticket" do
    ticket_id = open_ticket_via_api!

    post "#{PUBLIC_ROOT}/support_ticket_close/#{ticket_id}",
         headers: auth(@patron_token),
         as: :json

    assert_response :not_found
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

  test "ticket openapi titles are action first" do
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
    assert_equal "Open support ticket", public_ticket.openapi.dig(:create, :title)
    assert_equal "Update support ticket", operations_ticket.openapi.dig(:update, :title)
    assert_equal "List support tickets", public_ticket.openapi.dig(:index, :title)
    assert_equal "Show support ticket", operations_ticket.openapi.dig(:show, :title)
    assert_equal ["Support Ticket"], public_ticket.openapi.fetch(:tags)
    assert_equal "Support Ticket", public_ticket.openapi.dig(:tag, :group)
    assert_equal ["Support"], operations_ticket.openapi.fetch(:tags)
  end

  test "in-scope operations editor can update a ticket" do
    ticket_id = open_ticket_via_api!

    get "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success

    patch "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
          headers: auth(@editor_operations_token),
          params: { status: "resolved" },
          as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")
  end

  test "ticket update 404s for a foreign wrong-type or trashed id and the handler does not run" do
    foreign = ticket_under_other_admin_root
    trashed_id = open_ticket_via_api!
    RecordingStudio::Recording.find(trashed_id).update!(trashed_at: Time.current)

    [foreign.id, @center.id, trashed_id].each do |id|
      RecordingStudioSupport::Api::TicketUpdate.stub(:call, ->(*) { flunk "TicketUpdate ran for an out-of-scope id" }) do
        patch "#{OPERATIONS_ROOT}/support_tickets/#{id}",
              headers: auth(@editor_operations_token),
              params: { status: "resolved" },
              as: :json

        assert_response :not_found
      end
    end
  end

  private

  def ticket_under_other_admin_root
    record_as_support_team do
      other = AdminRoot.create!(name: "Other tickets #{SecureRandom.hex(4)}")
      root = RecordingStudio.create_root_recording!(other, actor: @support_user)
      center = root.record(RecordingStudioSupport::SupportCenter)
      root.record(RecordingStudioSupport::SupportTicket, parent_recording: center) do |ticket|
        ticket.subject = "Foreign ticket"
        ticket.status = "open"
        ticket.priority = "normal"
      end
    end
  end

  def record_as_support_team
    previous = Current.actor
    Current.actor = @support_user
    yield
  ensure
    Current.actor = previous
  end

  def ticket_status(ticket_id)
    get "#{OPERATIONS_ROOT}/support_tickets/#{ticket_id}",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success
    response.parsed_body.fetch("status")
  end

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
