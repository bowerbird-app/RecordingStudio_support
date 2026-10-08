# frozen_string_literal: true

require "test_helper"

class SupportApiTest < ActionDispatch::IntegrationTest
  PUBLIC_ROOT = "/recording_studio_api/api/v1"
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"

  setup do
    @staff = User.create!(
      email: "api-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace_user = User.create!(
      email: "api-ws-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @staff
    @workspace = Workspace.create!(name: "API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner!(@root, @staff)
    grant!(@root, @workspace_user, :edit)

    @section = record_support_section(@root, title: "API section #{SecureRandom.hex(4)}")
    @live = record_support_page(@root, @section, title: "Live API page #{SecureRandom.hex(4)}", body: "Live body")
    @draft = record_support_page(@root, @section, title: "Draft API page #{SecureRandom.hex(4)}", body: "Draft body")
    publish!(@live, slug: "live-api-#{SecureRandom.hex(4)}", status: "published")
    publish!(@draft, slug: "draft-api-#{SecureRandom.hex(4)}", status: "draft")

    @staff_public_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Staff public #{SecureRandom.hex(4)}",
      admin_root_recording: @admin_root
    )
    @editor_operations_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Staff operations #{SecureRandom.hex(4)}",
      api: :operations,
      admin_root_recording: @admin_root,
      admin_root_role: :edit
    )
    @viewer_operations_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :view,
      name: "Viewer operations #{SecureRandom.hex(4)}",
      api: :operations,
      admin_root_recording: @admin_root,
      admin_root_role: :view
    )
    @workspace_operations_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Workspace operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :view,
      name: "Workspace #{SecureRandom.hex(4)}"
    )
  end

  teardown do
    Current.actor = nil
  end

  test "missing token is unauthorized on the public API" do
    get "#{PUBLIC_ROOT}/support_pages", as: :json

    assert_response :unauthorized
  end

  test "public section routes are not found or unsupported" do
    get "#{PUBLIC_ROOT}/support_sections", headers: auth(@workspace_token), as: :json
    assert_public_resource_unavailable

    get "#{PUBLIC_ROOT}/support_sections/#{@section.id}", headers: auth(@workspace_token), as: :json
    assert_public_resource_unavailable

    get "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages", headers: auth(@workspace_token), as: :json
    assert_public_resource_unavailable

    get "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
        headers: auth(@workspace_token),
        as: :json
    assert_public_resource_unavailable
  end

  test "public writes and move are not found or unsupported" do
    post "#{PUBLIC_ROOT}/support_sections",
         headers: auth(@staff_public_token),
         params: { title: "Nope", parent_id: @root.id },
         as: :json
    assert_public_write_unavailable

    patch "#{PUBLIC_ROOT}/support_sections/#{@section.id}",
          headers: auth(@staff_public_token),
          params: { title: "Nope" },
          as: :json
    assert_public_write_unavailable

    delete "#{PUBLIC_ROOT}/support_sections/#{@section.id}",
           headers: auth(@staff_public_token),
           as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages",
         headers: auth(@staff_public_token),
         params: { title: "Nope" },
         as: :json
    assert_public_write_unavailable

    patch "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
          headers: auth(@staff_public_token),
          params: { title: "Nope" },
          as: :json
    assert_public_write_unavailable

    delete "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
           headers: auth(@staff_public_token),
           as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_pages",
         headers: auth(@staff_public_token),
         params: { title: "Nope", parent_id: @section.id },
         as: :json
    assert_public_write_unavailable

    patch "#{PUBLIC_ROOT}/support_pages/#{@live.id}",
          headers: auth(@staff_public_token),
          params: { title: "Nope" },
          as: :json
    assert_public_write_unavailable

    delete "#{PUBLIC_ROOT}/support_pages/#{@live.id}",
           headers: auth(@staff_public_token),
           as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_pages/#{@live.id}/actions/move",
         headers: auth(@staff_public_token),
         params: { parent_id: @section.id },
         as: :json
    assert_public_write_unavailable
  end

  test "operations editor token can write sections nested pages and pages including move" do
    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@editor_operations_token),
         params: { title: "Created section #{SecureRandom.hex(4)}", parent_id: @root.id, icon: "sparkles" },
         as: :json

    assert_response :created
    section_id = response.parsed_body.fetch("id")
    section_recordable_id = RecordingStudio::Recording.find(section_id).recordable_id

    patch "#{OPERATIONS_ROOT}/support_sections/#{section_id}",
          headers: auth(@editor_operations_token),
          params: { title: "Revised section" },
          as: :json

    assert_response :success
    assert_equal "Revised section", response.parsed_body.fetch("title")
    refute_equal section_recordable_id, RecordingStudio::Recording.find(section_id).recordable_id

    post "#{OPERATIONS_ROOT}/support_sections/#{section_id}/pages",
         headers: auth(@editor_operations_token),
         params: { title: "Nested page", body: "<p>Hello</p>" },
         as: :json

    assert_response :created
    page_id = response.parsed_body.fetch("id")
    assert_equal "Nested page", response.parsed_body.fetch("title")
    assert_equal "<p>Hello</p>", response.parsed_body.fetch("body")
    assert_equal section_id, RecordingStudio::Recording.find(page_id).parent_recording_id
    refute_equal page_id, RecordingStudio::Recording.find(page_id).recordable_id

    patch "#{OPERATIONS_ROOT}/support_sections/#{section_id}/pages/#{page_id}",
          headers: auth(@editor_operations_token),
          params: { title: "Revised nested" },
          as: :json

    assert_response :success
    assert_equal "Revised nested", response.parsed_body.fetch("title")
    refute_equal page_id, RecordingStudio::Recording.find(page_id).recordable_id

    post "#{OPERATIONS_ROOT}/support_pages",
         headers: auth(@editor_operations_token),
         params: { title: "Collection page", body: "<p>Hi</p>", parent_id: section_id },
         as: :json

    assert_response :created
    collection_page_id = response.parsed_body.fetch("id")

    patch "#{OPERATIONS_ROOT}/support_pages/#{collection_page_id}",
          headers: auth(@editor_operations_token),
          params: { title: "Revised collection" },
          as: :json

    assert_response :success
    assert_equal "Revised collection", response.parsed_body.fetch("title")

    destination = record_support_section(@root, title: "Move dest #{SecureRandom.hex(4)}")
    post "#{OPERATIONS_ROOT}/support_pages/#{page_id}/actions/move",
         headers: auth(@editor_operations_token),
         params: { parent_id: destination.id },
         as: :json

    assert_response :success
    assert_equal destination.id, RecordingStudio::Recording.find(page_id).reload.parent_recording_id

    delete "#{OPERATIONS_ROOT}/support_sections/#{destination.id}/pages/#{page_id}",
           headers: auth(@editor_operations_token),
           as: :json

    assert_response :success
    assert_equal "trashed", response.parsed_body.fetch("deleted_via")
    assert RecordingStudio::Recording.find(page_id).trashed_at

    delete "#{OPERATIONS_ROOT}/support_pages/#{collection_page_id}",
           headers: auth(@editor_operations_token),
           as: :json

    assert_response :success
    assert RecordingStudio::Recording.find(collection_page_id).trashed_at

    delete "#{OPERATIONS_ROOT}/support_sections/#{section_id}",
           headers: auth(@editor_operations_token),
           as: :json

    assert_response :success
    assert RecordingStudio::Recording.find(section_id).trashed_at
  end

  test "operations editor can create update and delete nested section pages" do
    post "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages",
         headers: auth(@editor_operations_token),
         params: { title: "HTTP nested #{SecureRandom.hex(4)}", body: "<p>Nested</p>" },
         as: :json

    assert_response :created
    page_id = response.parsed_body.fetch("id")
    assert_equal @section.id, RecordingStudio::Recording.find(page_id).parent_recording_id
    assert_equal "<p>Nested</p>", response.parsed_body.fetch("body")

    patch "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages/#{page_id}",
          headers: auth(@editor_operations_token),
          params: { title: "HTTP nested revised" },
          as: :json

    assert_response :success
    assert_equal "HTTP nested revised", response.parsed_body.fetch("title")
    refute_equal page_id, RecordingStudio::Recording.find(page_id).recordable_id

    delete "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages/#{page_id}",
           headers: auth(@editor_operations_token),
           as: :json

    assert_response :success
    assert_equal "trashed", response.parsed_body.fetch("deleted_via")
    assert RecordingStudio::Recording.find(page_id).trashed_at
  end

  test "public token is rejected on the operations API" do
    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@staff_public_token),
         params: { title: "Nope", parent_id: @root.id },
         as: :json

    assert_includes [401, 403], response.status, response.body
  end

  test "operations viewer is forbidden to write" do
    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@viewer_operations_token),
         params: { title: "Nope", parent_id: @root.id },
         as: :json

    assert_response :forbidden

    patch "#{OPERATIONS_ROOT}/support_pages/#{@live.id}",
          headers: auth(@viewer_operations_token),
          params: { title: "Hijack" },
          as: :json

    assert_response :forbidden

    delete "#{OPERATIONS_ROOT}/support_pages/#{@live.id}",
           headers: auth(@viewer_operations_token),
           as: :json

    assert_response :forbidden

    post "#{OPERATIONS_ROOT}/support_pages/#{@live.id}/actions/move",
         headers: auth(@viewer_operations_token),
         params: { parent_id: @section.id },
         as: :json

    assert_response :forbidden

    post "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages",
         headers: auth(@viewer_operations_token),
         params: { title: "Nope" },
         as: :json

    assert_response :forbidden

    patch "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
          headers: auth(@viewer_operations_token),
          params: { title: "Hijack" },
          as: :json

    assert_response :forbidden

    delete "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
           headers: auth(@viewer_operations_token),
           as: :json

    assert_response :forbidden
  end

  test "operations token without AdminRoot edit cannot write" do
    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@workspace_operations_token),
         params: { title: "Nope", parent_id: @root.id },
         as: :json

    assert_response :forbidden

    patch "#{OPERATIONS_ROOT}/support_pages/#{@live.id}",
          headers: auth(@workspace_operations_token),
          params: { title: "Hijack" },
          as: :json

    assert_response :forbidden
  end

  test "public index and show still work for staff and workspace tokens" do
    get "#{PUBLIC_ROOT}/support_pages", headers: auth(@staff_public_token), as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, @live.recordable.title
    assert_includes titles, @draft.recordable.title

    get "#{PUBLIC_ROOT}/support_pages/#{@draft.id}", headers: auth(@staff_public_token), as: :json

    assert_response :success
    assert_equal @draft.recordable.title, response.parsed_body.fetch("title")

    get "#{PUBLIC_ROOT}/support_pages", headers: auth(@workspace_token), as: :json

    assert_response :success
    workspace_titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes workspace_titles, @live.recordable.title
    refute_includes workspace_titles, @draft.recordable.title

    get "#{PUBLIC_ROOT}/support_pages/#{@live.id}", headers: auth(@workspace_token), as: :json

    assert_response :success

    get "#{PUBLIC_ROOT}/support_pages/#{@draft.id}", headers: auth(@workspace_token), as: :json

    assert_response :not_found
  end

  test "operations editor and viewer can read sections and nested pages" do
    get "#{OPERATIONS_ROOT}/support_sections", headers: auth(@editor_operations_token), as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, @section.recordable.title

    get "#{OPERATIONS_ROOT}/support_sections/#{@section.id}",
        headers: auth(@viewer_operations_token),
        as: :json

    assert_response :success
    assert_equal @section.recordable.title, response.parsed_body.fetch("title")

    get "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages",
        headers: auth(@viewer_operations_token),
        as: :json

    assert_response :success
    nested_titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes nested_titles, @live.recordable.title
    assert_includes nested_titles, @draft.recordable.title

    get "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages/#{@draft.id}",
        headers: auth(@viewer_operations_token),
        as: :json

    assert_response :success
    assert_equal @draft.recordable.title, response.parsed_body.fetch("title")

    get "#{OPERATIONS_ROOT}/support_sections", headers: auth(@staff_public_token), as: :json

    assert_includes [401, 403], response.status, response.body
  end

  test "general support search endpoint is gone" do
    get "#{PUBLIC_ROOT}/support/search",
        headers: auth(@workspace_token),
        params: { q: "billing" },
        as: :json

    assert_response :not_found
  end

  test "q searches nested section pages and the pages collection" do
    token = "Zephyr#{SecureRandom.hex(4)}"
    live_hit = record_support_page(@root, @section, title: "#{token} live receipt", body: "Body")
    draft_hit = record_support_page(@root, @section, title: "#{token} draft receipt", body: "Body")
    miss = record_support_page(@root, @section, title: "Unrelated #{SecureRandom.hex(4)}", body: "Body")
    publish!(live_hit, slug: "live-#{token}", status: "published")
    publish!(draft_hit, slug: "draft-#{token}", status: "draft")
    publish!(miss, slug: "miss-#{token}", status: "published")

    get "#{PUBLIC_ROOT}/support_pages",
        headers: auth(@staff_public_token),
        params: { q: token },
        as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, live_hit.recordable.title
    assert_includes titles, draft_hit.recordable.title
    refute_includes titles, miss.recordable.title
    assert_equal token, response.parsed_body.fetch("meta").fetch("q")

    get "#{PUBLIC_ROOT}/support_pages",
        headers: auth(@workspace_token),
        params: { q: token },
        as: :json

    assert_response :success
    workspace_titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes workspace_titles, live_hit.recordable.title
    refute_includes workspace_titles, draft_hit.recordable.title

    get "#{OPERATIONS_ROOT}/support_sections/#{@section.id}/pages",
        headers: auth(@editor_operations_token),
        as: :json

    assert_response :success
    nested_titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes nested_titles, live_hit.recordable.title
    assert_includes nested_titles, draft_hit.recordable.title
    assert_includes nested_titles, miss.recordable.title
  end

  private

  def assert_public_write_unavailable
    assert_includes [404, 422], response.status, response.body
  end

  def assert_public_resource_unavailable
    assert_includes [404, 422], response.status, response.body
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

  def publish!(page_recording, slug:, status:)
    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: page_recording,
      actor: @staff,
      attributes: { slug: slug, status: status }
    )
    raise result.error if result.failure?
  end
end
