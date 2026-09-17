# frozen_string_literal: true

require "test_helper"

class SupportApiTest < ActionDispatch::IntegrationTest
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
    grant!(@admin_root, @staff, :edit)
    bootstrap_owner!(@root, @staff)
    grant!(@root, @workspace_user, :edit)

    @section = record_support_section(@root, title: "API section #{SecureRandom.hex(4)}")
    @live = record_support_page(@root, @section, title: "Live API page #{SecureRandom.hex(4)}", body: "Live body")
    @draft = record_support_page(@root, @section, title: "Draft API page #{SecureRandom.hex(4)}", body: "Draft body")
    publish!(@live, slug: "live-api-#{SecureRandom.hex(4)}", status: "published")
    publish!(@draft, slug: "draft-api-#{SecureRandom.hex(4)}", status: "draft")

    @staff_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Staff #{SecureRandom.hex(4)}",
      admin_root_recording: @admin_root
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

  test "missing token is unauthorized" do
    get "/recording_studio_api/api/v1/support_sections", as: :json

    assert_response :unauthorized
  end

  test "admin-root client can crud sections and pages including nested create" do
    post "/recording_studio_api/api/v1/support_sections",
         headers: auth(@staff_token),
         params: { title: "Created section #{SecureRandom.hex(4)}", parent_id: @root.id, icon: "sparkles" },
         as: :json

    assert_response :created
    section_id = response.parsed_body.fetch("id")
    section_recordable_id = RecordingStudio::Recording.find(section_id).recordable_id

    patch "/recording_studio_api/api/v1/support_sections/#{section_id}",
          headers: auth(@staff_token),
          params: { title: "Revised section" },
          as: :json

    assert_response :success
    assert_equal "Revised section", response.parsed_body.fetch("title")
    refute_equal section_recordable_id, RecordingStudio::Recording.find(section_id).recordable_id

    post "/recording_studio_api/api/v1/support_sections/#{section_id}/pages",
         headers: auth(@staff_token),
         params: { title: "Nested page", body: "<p>Hello</p>" },
         as: :json

    assert_response :created
    page_id = response.parsed_body.fetch("id")
    assert_equal "Nested page", response.parsed_body.fetch("title")
    assert_equal "<p>Hello</p>", response.parsed_body.fetch("body")

    get "/recording_studio_api/api/v1/support_pages", headers: auth(@staff_token), as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, @live.recordable.title
    assert_includes titles, @draft.recordable.title

    get "/recording_studio_api/api/v1/support_pages/#{@draft.id}", headers: auth(@staff_token), as: :json

    assert_response :success
    assert_equal @draft.recordable.title, response.parsed_body.fetch("title")

    delete "/recording_studio_api/api/v1/support_pages/#{page_id}", headers: auth(@staff_token), as: :json

    assert_response :success
    assert_equal "trashed", response.parsed_body.fetch("deleted_via")
    assert RecordingStudio::Recording.find(page_id).trashed_at
  end

  test "workspace-only client can read live pages and is forbidden to write" do
    get "/recording_studio_api/api/v1/support_pages", headers: auth(@workspace_token), as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, @live.recordable.title
    refute_includes titles, @draft.recordable.title

    get "/recording_studio_api/api/v1/support_pages/#{@live.id}", headers: auth(@workspace_token), as: :json

    assert_response :success

    get "/recording_studio_api/api/v1/support_pages/#{@draft.id}", headers: auth(@workspace_token), as: :json

    assert_response :not_found

    post "/recording_studio_api/api/v1/support_sections",
         headers: auth(@workspace_token),
         params: { title: "Nope", parent_id: @root.id },
         as: :json

    assert_response :forbidden

    patch "/recording_studio_api/api/v1/support_pages/#{@live.id}",
          headers: auth(@workspace_token),
          params: { title: "Hijack" },
          as: :json

    assert_response :forbidden

    delete "/recording_studio_api/api/v1/support_pages/#{@live.id}", headers: auth(@workspace_token), as: :json

    assert_response :forbidden

    post "/recording_studio_api/api/v1/support_pages/#{@live.id}/actions/move",
         headers: auth(@workspace_token),
         params: { parent_id: @section.id },
         as: :json

    assert_response :forbidden
  end

  test "admin-root client can move a page between sections" do
    destination = record_support_section(@root, title: "Move dest #{SecureRandom.hex(4)}")

    post "/recording_studio_api/api/v1/support_pages/#{@live.id}/actions/move",
         headers: auth(@staff_token),
         params: { parent_id: destination.id },
         as: :json

    assert_response :success
    assert_equal destination.id, @live.reload.parent_recording_id
  end

  private

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, admin_root_recording: nil)
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name
    )
    raise result.error unless result.success?

    payload = result.value
    grant!(admin_root_recording, payload.fetch(:api_client), :edit) if admin_root_recording

    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token)
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
