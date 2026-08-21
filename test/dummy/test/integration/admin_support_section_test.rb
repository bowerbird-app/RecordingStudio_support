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

  test "admin help pages screen shows a real row" do
    get "/admin/screens/help_pages/table"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
  end

  test "admin support section is enabled on the dummy admin root" do
    assert_includes AdminRoot.recording_studio_admin_section_keys_for(nil, nil, nil), "support"
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
end
