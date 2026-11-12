# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SupportApiTest < ActionDispatch::IntegrationTest
  PUBLIC_ROOT = "/recording_studio_api/api/v1"
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"

  setup do
    @support_user = User.create!(
      email: "api-support-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace_user = User.create!(
      email: "api-ws-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @support_user
    @workspace = Workspace.create!(name: "API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant!(@admin_root, @support_user, :admin)
    bootstrap_owner!(@root, @support_user)
    grant!(@root, @workspace_user, :edit)

    @section = record_support_section(@root, title: "API section #{SecureRandom.hex(4)}")
    @live = record_support_page(@root, @section, title: "Live API page #{SecureRandom.hex(4)}", body: "Live body")
    @draft = record_support_page(@root, @section, title: "Draft API page #{SecureRandom.hex(4)}", body: "Draft body")
    publish!(@live, slug: "live-api-#{SecureRandom.hex(4)}", status: "published")
    publish!(@draft, slug: "draft-api-#{SecureRandom.hex(4)}", status: "draft")

    @support_public_token = provision_token(
      access_point: @root,
      actor: @support_user,
      role: :edit,
      name: "Support team public #{SecureRandom.hex(4)}",
      admin_root_recording: @admin_root
    )
    @editor_operations_token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :edit,
      name: "Support operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    @viewer_operations_token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :view,
      name: "Viewer operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_operations_token = provision_token(
      access_point: @root,
      actor: @support_user,
      role: :edit,
      name: "Workspace operations #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_token = provision_token(
      access_point: @root,
      actor: @support_user,
      role: :view,
      name: "Workspace #{SecureRandom.hex(4)}"
    )
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "missing token is unauthorized on the public API" do
    get "#{PUBLIC_ROOT}/support_pages", as: :json

    assert_response :unauthorized
  end

  test "operations editor can list show and create support centers" do
    center = RecordingStudioSupport::SupportCenters.current

    get "#{OPERATIONS_ROOT}/support_centers", headers: auth(@editor_operations_token), as: :json

    assert_response :success
    ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    assert_includes ids, center.id

    get "#{OPERATIONS_ROOT}/support_centers/#{center.id}",
        headers: auth(@viewer_operations_token),
        as: :json

    assert_response :success
    assert_equal center.id, response.parsed_body.fetch("id")
    assert_equal "RecordingStudioSupport::SupportCenter", response.parsed_body.fetch("type")

    post "#{OPERATIONS_ROOT}/support_centers",
         headers: auth(@editor_operations_token),
         params: { parent_id: @admin_root.id },
         as: :json

    assert_response :created
    created_id = response.parsed_body.fetch("id")
    created = RecordingStudio::Recording.find(created_id)
    assert_equal "RecordingStudioSupport::SupportCenter", created.recordable_type
    assert_equal @admin_root.id, created.parent_recording_id
  end

  test "public cannot list show or create support centers" do
    center = RecordingStudioSupport::SupportCenters.current

    get "#{PUBLIC_ROOT}/support_centers", headers: auth(@workspace_token), as: :json
    assert_public_resource_unavailable

    get "#{PUBLIC_ROOT}/support_centers/#{center.id}", headers: auth(@workspace_token), as: :json
    assert_public_resource_unavailable

    post "#{PUBLIC_ROOT}/support_centers",
         headers: auth(@support_public_token),
         params: { parent_id: @admin_root.id },
         as: :json
    assert_public_write_unavailable
  end

  test "support center create rejects a workspace parent" do
    post "#{OPERATIONS_ROOT}/support_centers",
         headers: auth(@editor_operations_token),
         params: { parent_id: @root.id },
         as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    details = body["details"] || body.dig("error", "details") || []
    assert_predicate details, :present?, body
    assert(details.any? { |detail| detail.fetch("attribute").to_s == "parent_id" }, body)
  end

  test "support center create maps InvalidParent to invalid_input" do
    boom = lambda do |**|
      raise RecordingStudio::InvalidParent, "RecordingStudioSupport::SupportCenter cannot be recorded under AdminRoot"
    end
    RecordingStudioSupport::SupportCenters.stub(:create!, boom) do
      post "#{OPERATIONS_ROOT}/support_centers",
           headers: auth(@editor_operations_token),
           params: { parent_id: @admin_root.id },
           as: :json
    end

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "invalid_input", body["code"] || body.dig("error", "code")
    details = body["details"] || body.dig("error", "details") || []
    assert_predicate details, :present?, body
    assert(details.any? { |detail| detail.fetch("attribute").to_s == "parent_id" }, body)
  end

  test "operations token without AdminRoot access is forbidden on support centers" do
    get "#{OPERATIONS_ROOT}/support_centers", headers: auth(@workspace_operations_token), as: :json

    assert_response :forbidden

    post "#{OPERATIONS_ROOT}/support_centers",
         headers: auth(@workspace_operations_token),
         params: { parent_id: @admin_root.id },
         as: :json

    assert_response :forbidden
  end

  test "page create with a non-section parent is a client error" do
    post "#{OPERATIONS_ROOT}/support_pages",
         headers: auth(@editor_operations_token),
         params: { title: "Orphan page", body: "<p>Hi</p>", parent_id: @admin_root.id },
         as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    details = body["details"] || body.dig("error", "details") || []
    assert_predicate details, :present?, body
    assert(details.any? { |detail| detail.fetch("attribute").to_s == "parent_id" }, body)
  end

  test "section create with an invalid parent is a client error" do
    boom = lambda do |**|
      raise RecordingStudio::InvalidParent, "RecordingStudioSupport::SupportSection cannot be recorded under AdminRoot"
    end
    RecordingStudioSupport::Sections.stub(:create!, boom) do
      post "#{OPERATIONS_ROOT}/support_sections",
           headers: auth(@editor_operations_token),
           params: { title: "Wrong parent section", parent_id: @admin_root.id },
           as: :json
    end

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "invalid_input", body["code"] || body.dig("error", "code")
    details = body["details"] || body.dig("error", "details") || []
    assert_predicate details, :present?, body
    assert(details.any? { |detail| detail.fetch("attribute").to_s == "parent_id" }, body)
  end

  test "section create without a support center is a client error" do
    RecordingStudioSupport::SupportCenters.kept.update_all(trashed_at: Time.current)

    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@editor_operations_token),
         params: { title: "Orphan section", parent_id: @admin_root.id },
         as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    details = body["details"] || body.dig("error", "details") || []
    assert_predicate details, :present?, body
    assert(details.any? { |detail| detail.fetch("attribute").to_s == "parent_id" }, body)
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
         headers: auth(@support_public_token),
         params: { title: "Nope", parent_id: @root.id },
         as: :json
    assert_public_write_unavailable

    patch "#{PUBLIC_ROOT}/support_sections/#{@section.id}",
          headers: auth(@support_public_token),
          params: { title: "Nope" },
          as: :json
    assert_public_write_unavailable

    delete "#{PUBLIC_ROOT}/support_sections/#{@section.id}",
           headers: auth(@support_public_token),
           as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages",
         headers: auth(@support_public_token),
         params: { title: "Nope" },
         as: :json
    assert_public_write_unavailable

    patch "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
          headers: auth(@support_public_token),
          params: { title: "Nope" },
          as: :json
    assert_public_write_unavailable

    delete "#{PUBLIC_ROOT}/support_sections/#{@section.id}/pages/#{@live.id}",
           headers: auth(@support_public_token),
           as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_pages",
         headers: auth(@support_public_token),
         params: { title: "Nope", parent_id: @section.id },
         as: :json
    assert_public_write_unavailable

    patch "#{PUBLIC_ROOT}/support_pages/#{@live.id}",
          headers: auth(@support_public_token),
          params: { title: "Nope" },
          as: :json
    assert_public_write_unavailable

    delete "#{PUBLIC_ROOT}/support_pages/#{@live.id}",
           headers: auth(@support_public_token),
           as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_pages/#{@live.id}/actions/move",
         headers: auth(@support_public_token),
         params: { parent_id: @section.id },
         as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_pages/#{@live.id}/actions/publish",
         headers: auth(@support_public_token),
         as: :json
    assert_public_write_unavailable

    post "#{PUBLIC_ROOT}/support_pages/#{@live.id}/actions/unpublish",
         headers: auth(@support_public_token),
         as: :json
    assert_public_write_unavailable
  end

  test "operations editor token can write sections nested pages and pages including move" do
    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@editor_operations_token),
         params: { title: "Created section #{SecureRandom.hex(4)}", parent_id: @admin_root.id, icon: "sparkles" },
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

    destination = record_as_support_team { record_support_section(@root, title: "Move dest #{SecureRandom.hex(4)}") }
    alias_dest = record_as_support_team { record_support_section(@root, title: "Alias dest #{SecureRandom.hex(4)}") }
    post "#{OPERATIONS_ROOT}/support_pages/#{page_id}/actions/move",
         headers: auth(@editor_operations_token),
         params: { destination_id: destination.id },
         as: :json

    assert_response :success
    assert_equal destination.id, RecordingStudio::Recording.find(page_id).reload.parent_recording_id

    post "#{OPERATIONS_ROOT}/support_pages/#{page_id}/actions/move",
         headers: auth(@editor_operations_token),
         params: { new_parent_id: alias_dest.id },
         as: :json

    assert_response :success
    assert_equal alias_dest.id, RecordingStudio::Recording.find(page_id).reload.parent_recording_id

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

  test "section create rejects a trashed workspace parent" do
    trashed = record_as_support_team do
      workspace = Workspace.create!(name: "Trashed #{SecureRandom.hex(4)}")
      root = RecordingStudio.root_recording_for(workspace)
      bootstrap_owner!(root, @support_user)
      root.update!(trashed_at: Time.current)
      root
    end

    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@editor_operations_token),
         params: { title: "Orphan", parent_id: trashed.id },
         as: :json

    assert_response :not_found
  end

  test "public token is rejected on the operations API" do
    post "#{OPERATIONS_ROOT}/support_sections",
         headers: auth(@support_public_token),
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

    post "#{OPERATIONS_ROOT}/support_pages/#{@live.id}/actions/publish",
         headers: auth(@viewer_operations_token),
         as: :json

    assert_response :forbidden

    post "#{OPERATIONS_ROOT}/support_pages/#{@live.id}/actions/unpublish",
         headers: auth(@viewer_operations_token),
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

    post "#{OPERATIONS_ROOT}/support_pages/#{@live.id}/actions/publish",
         headers: auth(@workspace_operations_token),
         as: :json

    assert_response :forbidden

    post "#{OPERATIONS_ROOT}/support_pages/#{@live.id}/actions/move",
         headers: auth(@workspace_operations_token),
         params: { parent_id: @section.id },
         as: :json

    assert_response :forbidden

    delete "#{OPERATIONS_ROOT}/support_pages/#{@live.id}",
           headers: auth(@workspace_operations_token),
           as: :json

    assert_response :forbidden
  end

  test "operations support team without workspace grant can move and trash through mixins" do
    ops_support_user = User.create!(
      email: "ops-only-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    grant!(@admin_root, ops_support_user, :edit)
    refute RecordingStudioAccessible.authorized?(actor: ops_support_user, recording: @root, role: :edit)

    token = provision_token(
      access_point: @admin_root,
      actor: @support_user,
      role: :edit,
      name: "Ops only #{SecureRandom.hex(4)}",
      api: :operations
    )

    page = record_as_support_team { record_support_page(@root, @section, title: "Ops move #{SecureRandom.hex(4)}", body: "Body") }
    destination = record_as_support_team { record_support_section(@root, title: "Ops dest #{SecureRandom.hex(4)}") }
    events_before = RecordingStudio::Event.where(recording_id: page.id).count

    post "#{OPERATIONS_ROOT}/support_pages/#{page.id}/actions/move",
         headers: auth(token),
         params: { parent_id: destination.id },
         as: :json

    assert_response :success
    page.reload
    assert_equal destination.id, page.parent_recording_id
    moved_events = RecordingStudio::Event.where(recording_id: page.id, action: "moved")
    assert_operator RecordingStudio::Event.where(recording_id: page.id).count, :>, events_before
    assert moved_events.exists?
    metadata = moved_events.order(:id).last.metadata
    assert metadata["from_root_id"].present? || metadata[:from_root_id].present?

    delete "#{OPERATIONS_ROOT}/support_pages/#{page.id}",
           headers: auth(token),
           as: :json

    assert_response :success
    assert page.reload.trashed_at
  end

  test "operations publish and unpublish control public visibility" do
    token = "Publish#{SecureRandom.hex(4)}"
    post "#{OPERATIONS_ROOT}/support_pages",
         headers: auth(@editor_operations_token),
         params: {
           title: "#{token} operations draft",
           body: "<p>#{token}</p>",
           parent_id: @section.id
         },
         as: :json

    assert_response :created
    page_id = response.parsed_body.fetch("id")
    refute RecordingStudioSupport::SupportPage.find(
      RecordingStudio::Recording.find(page_id).recordable_id
    ).indexable?

    get "#{PUBLIC_ROOT}/support_pages/#{page_id}", headers: auth(@workspace_token), as: :json
    assert_response :not_found

    get "#{PUBLIC_ROOT}/support_pages",
        headers: auth(@workspace_token),
        params: { q: token },
        as: :json

    assert_response :success
    refute_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, page_id

    post "#{OPERATIONS_ROOT}/support_pages/#{page_id}/actions/publish",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success
    assert_equal "published", response.parsed_body.fetch("status")
    assert RecordingStudioSupport::SupportPage.find(
      RecordingStudio::Recording.find(page_id).recordable_id
    ).indexable?

    get "#{PUBLIC_ROOT}/support_pages/#{page_id}", headers: auth(@workspace_token), as: :json
    assert_response :success
    assert_equal "#{token} operations draft", response.parsed_body.fetch("title")

    get "#{PUBLIC_ROOT}/support_pages",
        headers: auth(@workspace_token),
        params: { q: token },
        as: :json

    assert_response :success
    assert_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, page_id

    post "#{OPERATIONS_ROOT}/support_pages/#{page_id}/actions/unpublish",
         headers: auth(@editor_operations_token),
         as: :json

    assert_response :success
    assert_equal "draft", response.parsed_body.fetch("status")
    refute RecordingStudioSupport::SupportPage.find(
      RecordingStudio::Recording.find(page_id).recordable_id
    ).indexable?

    get "#{PUBLIC_ROOT}/support_pages/#{page_id}", headers: auth(@workspace_token), as: :json
    assert_response :not_found

    get "#{PUBLIC_ROOT}/support_pages",
        headers: auth(@workspace_token),
        params: { q: token },
        as: :json

    assert_response :success
    refute_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, page_id
  end

  test "public index and show still work for the support team and workspace tokens" do
    get "#{PUBLIC_ROOT}/support_pages", headers: auth(@support_public_token), as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, @live.recordable.title
    assert_includes titles, @draft.recordable.title

    get "#{PUBLIC_ROOT}/support_pages/#{@draft.id}", headers: auth(@support_public_token), as: :json

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

  test "describe operations match public reads and Admin writes" do
    public_page = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioSupport::SupportPage",
      api: :public
    )
    operations_page = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioSupport::SupportPage",
      api: :operations
    )
    operations_section = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioSupport::SupportSection",
      api: :operations
    )
    operations_center = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioSupport::SupportCenter",
      api: :operations
    )

    assert_equal %i[index show], public_page.operations
    refute public_page.supports_operation?(:update)
    refute public_page.supports_operation?(:create)
    refute public_page.supports_operation?(:destroy)

    assert_equal %i[create destroy index show update], operations_page.operations
    assert operations_page.supports_operation?(:update)
    assert operations_page.supports_operation?(:create)
    assert operations_page.supports_operation?(:destroy)
    assert_equal %w[move publish unpublish], operations_page.capability_actions

    assert_equal %i[create destroy index show update], operations_section.operations
    assert operations_section.supports_operation?(:update)

    assert_equal %i[create index show], operations_center.operations
    refute operations_center.supports_operation?(:update)

    expected_openapi = RecordingStudioSupport::Api::SUPPORT_OPENAPI
    assert_equal expected_openapi, public_page.openapi
    assert_equal expected_openapi, operations_page.openapi
    assert_equal expected_openapi, operations_section.openapi
    assert_equal expected_openapi, operations_center.openapi
    assert_equal ["Support"], public_page.openapi.fetch(:tags)
    assert_equal "Support", public_page.openapi.dig(:tag, :group)
  end

  test "page and section lists accept an API Page pagination payload" do
    service = RecordingStudioApi::Services::PaginateResourceCollection
    original = service.method(:call)
    section_rows = RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioSupport::SupportSection",
      trashed_at: nil
    ).limit(5).to_a
    page_class = Data.define(:rows, :meta)
    fake_result = Struct.new(:value) do
      def failure?
        false
      end
    end
    service = RecordingStudioApi::Services::PaginateResourceCollection
    original = service.method(:call)

    service.define_singleton_method(:call) do |**_kwargs|
      fake_result.new(page_class.new(section_rows, { limit: 50, has_more: false }))
    end

    get "#{OPERATIONS_ROOT}/support_sections", headers: auth(@editor_operations_token), as: :json

    assert_response :success
    assert_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, @section.id
  ensure
    service.define_singleton_method(:call, original)
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

    get "#{OPERATIONS_ROOT}/support_sections", headers: auth(@support_public_token), as: :json

    assert_includes [401, 403], response.status, response.body
  end

  test "general support search endpoint is gone" do
    get "#{PUBLIC_ROOT}/support/search",
        headers: auth(@workspace_token),
        params: { q: "billing" },
        as: :json

    assert_response :not_found
  end

  test "q filters the operations section index" do
    token = "Quorum#{SecureRandom.hex(4)}"
    hit, miss = record_as_support_team do
      [
        record_support_section(@root, title: "#{token} billing"),
        record_support_section(@root, title: "Unrelated #{SecureRandom.hex(4)}")
      ]
    end

    get "#{OPERATIONS_ROOT}/support_sections",
        headers: auth(@editor_operations_token),
        params: { q: token },
        as: :json

    assert_response :success
    titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes titles, hit.recordable.title
    refute_includes titles, miss.recordable.title
    assert_equal token, response.parsed_body.fetch("meta").fetch("q")
  end

  test "q searches nested section pages and the pages collection" do
    token = "Zephyr#{SecureRandom.hex(4)}"
    live_hit, draft_hit, miss = record_as_support_team do
      [
        record_support_page(@root, @section, title: "#{token} live receipt", body: "Body"),
        record_support_page(@root, @section, title: "#{token} draft receipt", body: "Body"),
        record_support_page(@root, @section, title: "Unrelated #{SecureRandom.hex(4)}", body: "Body")
      ]
    end
    record_as_support_team do
      publish!(live_hit, slug: "live-#{token}", status: "published")
      publish!(draft_hit, slug: "draft-#{token}", status: "draft")
      publish!(miss, slug: "miss-#{token}", status: "published")
    end

    get "#{PUBLIC_ROOT}/support_pages",
        headers: auth(@support_public_token),
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
        params: { q: token },
        as: :json

    assert_response :success
    nested_titles = response.parsed_body.fetch("records").map { |record| record.fetch("title") }
    assert_includes nested_titles, live_hit.recordable.title
    assert_includes nested_titles, draft_hit.recordable.title
    refute_includes nested_titles, miss.recordable.title
    assert_equal token, response.parsed_body.fetch("meta").fetch("q")
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

  def record_as_support_team
    previous = Current.actor
    Current.actor = @support_user
    yield
  ensure
    Current.actor = previous
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

  def publish!(page_recording, slug:, status:)
    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: page_recording,
      actor: @support_user,
      attributes: { slug: slug, status: status }
    )
    raise result.error if result.failure?
  end
end
