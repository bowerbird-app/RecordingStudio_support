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

  test "admin support section shows a page count and two table links" do
    get "/admin"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_flatpack_rounded_theme
    assert_includes response.body, "Help"
    assert_includes response.body, "Support pages"
    assert_includes response.body, "Support sections"
    assert_includes response.body, "/admin/screens/support_pages"
    assert_includes response.body, "/admin/screens/support_sections"
    refute_includes response.body, "See every page"
    refute_includes response.body, "Latest pages"
    refute_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    refute_includes response.body, "Reads"
    refute_match(/>\s*Help pages\s*</, response.body)
    assert_includes response.body, "flat_pack/application"
    refute_includes response.body, "recordable"
  end

  test "admin support pages table lists draft and published pages" do
    get "/admin/screens/support_pages"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_flatpack_rounded_theme
    assert_includes response.body, "Support pages"
    assert_includes response.body, "New page"
    assert_includes response.body, "/support/new"
    assert_includes response.body, 'name="search"'
    assert_includes response.body, 'name="status"'
    assert_includes response.body, 'name="section"'
    assert_includes response.body, "Published"
    assert_includes response.body, "Draft"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Studio Workspace"
    refute_includes response.body, "recordable"
    refute_includes response.body, "Table data"
    refute_includes response.body, "2 rows"
    refute_includes response.body, 'id="screen-table-count"'

    get "/admin/screens/support_pages/table"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, "Published"
    assert_includes response.body, "Draft"
    assert_includes response.body, "Edit"
    assert_includes response.body, "--table-border-color"
    assert_includes response.body, "<table"
    refute_includes response.body, "Table data"
    refute_includes response.body, "2 rows"
    refute_includes response.body, 'id="screen-table-count"'
    sign_in_edit = RecordingStudioSupport::Admin::Queries.edit_page_path(
      seeded_page("How do I sign in?")
    )
    password_edit = RecordingStudioSupport::Admin::Queries.edit_page_path(
      seeded_page("How do I change my password?")
    )
    assert_includes response.body, sign_in_edit
    assert_includes response.body, password_edit
  end

  test "admin support pages table filters by search and publish status" do
    get "/admin/screens/support_pages/table", params: { search: "change my password" }

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I sign in?"

    get "/admin/screens/support_pages/table", params: { search: "account settings" }

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I sign in?"

    get "/admin/screens/support_pages/table", params: { status: "Published" }

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"

    get "/admin/screens/support_pages/table", params: { status: "Draft" }

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I sign in?"

    get "/admin/screens/support_pages/table", params: { section: "Getting started" }

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I update payment details?"

    get "/admin/screens/support_pages/table", params: { section: "Billing" }

    assert_response :success
    assert_includes response.body, "How do I update payment details?"
    refute_includes response.body, "How do I sign in?"
  end

  test "admin support sections table lists sections" do
    get "/admin/screens/support_sections"

    assert_response :success
    assert_includes response.body, "Support sections"
    assert_includes response.body, "New section"
    assert_includes response.body, "/support/sections/new"

    get "/admin/screens/support_sections/table"

    assert_response :success
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Billing"
    assert_includes response.body, "Developers"
    assert_includes response.body, "Count"
    assert_includes response.body, "Edit"
    assert_includes response.body, "<table"
    refute_includes response.body, "1 page"
    refute_includes response.body, "2 pages"
    refute_includes response.body, "1 pages"
    refute_includes response.body, "2 page"
    assert_equal(
      { "Billing" => "1", "Developers" => "1", "Getting started" => "2" },
      section_page_counts_from_table(response.body)
    )
    getting_started_edit = RecordingStudioSupport::Admin::Queries.edit_section_path(
      seeded_section("Getting started")
    )
    assert_includes response.body, getting_started_edit
  end

  test "edit is reachable from the admin table" do
    recording = seeded_page("How do I change my password?")

    get "/admin/screens/support_pages/table"

    assert_response :success
    assert_includes response.body, "/support/#{recording.id}/edit"

    get "/support/#{recording.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit page"
    assert_includes response.body, "flat-pack-richtext-wrapper"
    assert_includes response.body, "flat-pack--tiptap"
    assert_includes response.body, "Save"
    assert_includes response.body, "Cancel"
    assert_includes response.body, "/admin/screens/support_pages"
    assert_select "input[name='page[title]']"
  end

  test "section edit is reachable from the admin sections table" do
    section = seeded_section("Getting started")

    get "/support/sections/#{section.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit section"
    assert_includes response.body, "Save"
    assert_includes response.body, "Cancel"
    assert_includes response.body, "/admin/screens/support_sections"
    refute_includes response.body, "flat-pack-button-group"
  end

  test "admin support section hides host chrome and keeps access" do
    get "/admin"

    assert_response :success
    refute_includes response.body, "Sign out"
    refute_includes response.body, "/users/sign_out"
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "Support pages"
    refute_includes response.body, "See every page"
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

  def section_page_counts_from_table(html)
    document = Nokogiri::HTML(html)
    headers = document.css("thead th").map { |cell| cell.text.gsub(/\s+/, " ").strip }
    count_index = headers.index { |header| header == "Count" }
    raise "Count column missing from #{headers.inspect}" unless count_index

    document.css("tbody tr").each_with_object({}) do |row, counts|
      cells = row.css("td").map { |cell| cell.text.gsub(/\s+/, " ").strip }
      name = cells[0]
      next if name.blank?

      counts[name] = cells[count_index]
    end
  end

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
end
