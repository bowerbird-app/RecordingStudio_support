# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminSupportSectionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
    switch_to_admin_root!
  end

  test "admin support section lists pages and non-zero widgets" do
    get "/admin"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "body[data-theme='rounded']"
    assert_includes response.body, "Help"
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, "Help pages"
    assert_includes response.body, "Reads"
    assert_includes response.body, "flat_pack/application"
    refute_includes response.body, "recordable"
    assert_operator RecordingStudioSupport::PageView.count, :>=, 1
  end

  test "admin help pages table lists draft and published pages" do
    get "/admin/screens/help_pages"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "html[data-theme='rounded']"
    assert_includes response.body, "Help pages"
    assert_includes response.body, "/support/new"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Studio Workspace"
    refute_includes response.body, "recordable"

    get "/admin/screens/help_pages/table"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, "Published"
    assert_includes response.body, "Draft"
    assert_includes response.body, "Edit"
    assert_includes response.body, "--table-border-color"
    assert_includes response.body, "<table"
    sign_in_edit = RecordingStudioSupport::Admin::Queries.edit_page_path(
      seeded_page("How do I sign in?")
    )
    password_edit = RecordingStudioSupport::Admin::Queries.edit_page_path(
      seeded_page("How do I change my password?")
    )
    assert_includes response.body, sign_in_edit
    assert_includes response.body, password_edit
  end

  test "edit is reachable from the admin table" do
    recording = seeded_page("How do I change my password?")

    get "/admin/screens/help_pages/table"

    assert_response :success
    assert_includes response.body, "/support/#{recording.id}/edit"

    get "/support/#{recording.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit page"
    assert_includes response.body, "flat-pack-richtext-wrapper"
    assert_includes response.body, "flat-pack--tiptap"
    assert_select "input[name='page[title]']"
  end

  test "admin support section hides host chrome and keeps access" do
    get "/admin"

    assert_response :success
    refute_includes response.body, "Sign out"
    refute_includes response.body, "/users/sign_out"
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "See every page"
    refute_includes response.body, "Open help pages"
  end

  test "admin support section is enabled on the dummy admin root" do
    assert_includes AdminRoot.recording_studio_admin_section_keys_for(nil, nil, nil), "support"
  end

  test "staff with admin root access can edit without a workspace grant" do
    staff = User.create!(
      email: "admin-editor-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    admin_root_recording = RecordingStudio.root_recording_for(AdminRoot.find_by!(name: "Admin"))
    grant_role!(admin_root_recording, staff, :admin)
    sign_in staff
    switch_to_admin_root!

    recording = seeded_page("How do I change my password?")
    get "/support/#{recording.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit page"
  end

  test "viewer without admin access is forbidden" do
    stranger = User.create!(
      email: "admin-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in stranger

    get "/admin"

    assert_response :forbidden
  end

  private

  def switch_to_admin_root!
    admin_root = AdminRoot.find_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: admin_root_recording.id,
        return_to: "/admin"
      }
    }
  end

  def grant_role!(recording, actor, role)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: actor
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end

  def seeded_page(title)
    RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioSupport::SupportPage",
      trashed_at: nil
    ).find { |recording| recording.recordable.title == title }
  end
end
