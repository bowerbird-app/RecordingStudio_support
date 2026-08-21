# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportPagesUiTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
  end

  test "index lists seeded help pages with default layout chrome" do
    get "/support"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, "New page"
    assert_includes response.body, "flat-pack-page-nav"
    assert_includes response.body, "Studio Workspace"
    assert_includes response.body, "flat_pack/application"
    refute_includes response.body, "recordable"
    refute_includes response.body, "This app proves the support gem"
  end

  test "show renders title, body, and attached image" do
    recording = seeded_page("How do I sign in?")

    get "/support/#{recording.id}"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "Use the email and password you were given"
    assert_includes response.body, "sign-in.png"
    assert_select "img[alt='sign-in.png']"
    assert_includes response.body, "Edit"
    assert_includes response.body, "Move to trash"
    assert RecordingStudioSupport::PageView.exists?(recording_id: recording.id)
  end

  test "new and create go through public record helper" do
    get "/support/new"

    assert_response :success
    assert_includes response.body, "New page"
    assert_select "input[name='page[title]']"
    assert_select "textarea[name='page[body]']"

    assert_difference -> { RecordingStudioSupport::SupportPage.count }, 1 do
      post "/support", params: {
        page: {
          title: "How do I invite a teammate?",
          body: "Ask someone with access to send them an invite."
        }
      }
    end

    recording = RecordingStudio::Recording.order(:created_at).last
    assert_redirected_to "/support/#{recording.id}"
    follow_redirect!
    assert_includes response.body, "How do I invite a teammate?"
    assert_includes response.body, "Saved. That should help someone."
  end

  test "edit revises the page instead of saving in place" do
    recording = seeded_page("How do I change my password?")
    original_id = recording.recordable_id

    get "/support/#{recording.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit page"
    assert_select "input[name='page[title]']"

    patch "/support/#{recording.id}", params: {
      page: {
        title: "How do I change my password?",
        body: "Pick a new password, then sign in with it."
      }
    }

    assert_redirected_to "/support/#{recording.id}"
    recording.reload
    assert_not_equal original_id, recording.recordable_id
    assert_equal "Pick a new password, then sign in with it.", recording.recordable.body
  end

  test "viewer with view access can read but not write" do
    viewer = User.create!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace = Workspace.find_by!(name: "Studio Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_role!(root_recording, viewer, :view)
    sign_in viewer

    get "/support"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "New page"

    get "/support/new"

    assert_response :forbidden
  end

  test "viewer without access is forbidden" do
    stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in stranger

    get "/support"

    assert_response :forbidden
  end

  test "trash uses the trashable helper and leaves the index" do
    recording = seeded_page("How do I change my password?")

    post "/support/#{recording.id}/trash"

    assert_response :redirect
    assert_match(%r{/support/?\z}, response.redirect_url)
    assert recording.reload.trashed_at
    get "/support"
    refute_includes response.body, "How do I change my password?"
  end

  private

  def seeded_page(title)
    RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioSupport::SupportPage",
      trashed_at: nil
    ).find { |recording| recording.recordable.title == title }
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
