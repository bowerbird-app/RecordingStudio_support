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
    assert_includes response.body, "Help"
    assert_includes response.body, "Answers you can share."
    assert_includes response.body, "flat_pack/application"
    assert_select "body[data-theme='rounded']"
    assert_select "a[aria-label='Close'][href='/']"
    refute_select ".flat-pack-page-nav a", text: /Sign out/
    refute_includes response.body, "Studio Workspace"
    refute_includes response.body, "/users/sign_out"
    refute_includes response.body, "recordable"
    refute_includes response.body, "This app proves the support gem"
    assert_select "input[name='q']"
  end

  test "index uses configured help titles" do
    previous_title = RecordingStudioSupport.configuration.pages_title
    previous_subtitle = RecordingStudioSupport.configuration.pages_subtitle
    RecordingStudioSupport.configuration.pages_title = "Guides"
    RecordingStudioSupport.configuration.pages_subtitle = "Short answers."

    get "/support"

    assert_response :success
    assert_includes response.body, "Guides"
    assert_includes response.body, "Short answers."
    refute_includes response.body, "Answers you can share."
  ensure
    RecordingStudioSupport.configuration.pages_title = previous_title
    RecordingStudioSupport.configuration.pages_subtitle = previous_subtitle
  end

  test "index ILIKE search matches title and body" do
    get "/support", params: { q: "sign in" }

    assert_response :success
    assert_select "body[data-theme='rounded']"
    assert_select "form[role='search'][class~='w-full']"
    assert_includes response.body, "max-w-none"
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    assert_select "input[name='q'][value='sign in']"
  end

  test "index search empty state is human" do
    get "/support", params: { q: "no-such-help-page" }

    assert_response :success
    assert_includes response.body, "Nothing matches that"
    assert_includes response.body, "Try another word."
    refute_includes response.body, "How do I sign in?"
    refute_includes response.body, "recordable"
  end

  test "show renders title, body, and attached image" do
    recording = seeded_page("How do I sign in?")

    get "/support/#{recording.id}"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "Use the email and password you were given"
    assert_includes response.body, "sign-in.png"
    assert_select "img[alt='sign-in.png']"
    close = css_select("a[aria-label='Close']").first
    assert close
    assert_match(%r{\A/support/?\z}, close["href"])
    refute_select ".flat-pack-page-nav a", text: /Sign out/
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "Edit"
    assert_includes response.body, "Move to trash"
    assert RecordingStudioSupport::PageView.exists?(recording_id: recording.id)
  end

  test "show renders sanitized HTML and drops inline images" do
    recording = RecordingStudioSupport::Pages.create!(
      root_recording: RecordingStudio.root_recording_for(Workspace.find_by!(name: "Studio Workspace")),
      title: "Printer jam",
      body: "<p>Turn it off.</p><h2>Then on</h2><img src=\"https://example.test/x.png\" alt=\"nope\">",
      actor: @user
    )

    get "/support/#{recording.id}"

    assert_response :success
    assert_select "p", text: "Turn it off."
    assert_select "h2", text: "Then on"
    refute_includes response.body, "&lt;p&gt;"
    refute_select "img[alt='nope']"
  end

  test "new and create go through public record helper" do
    get "/support/new"

    assert_response :success
    assert_includes response.body, "New page"
    assert_select "input[name='page[title]']"
    assert_select "input[type='hidden'][name='page[body]']"
    assert_includes response.body, "flat-pack-richtext-wrapper"
    assert_includes response.body, "flat-pack--tiptap"
    refute_includes response.body, "Words only"
    refute_includes response.body, "Pictures live under the page"

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
    refute_includes response.body, "Fix the wording"
    refute_includes response.body, "Keep the pictures where they are"
    refute_includes response.body, "Words only"
    assert_includes response.body, "flat-pack-richtext-wrapper"
    assert_includes response.body, "flat-pack--tiptap"
    assert_includes response.body, "Open your account settings and pick a new password"
    assert_includes File.read(Rails.root.join("app/javascript/controllers/index.js")),
                    'application.register("flat-pack--tiptap", TiptapController)'
    assert_select "input[name='page[title]']"
    assert_select "input[type='hidden'][name='page[body]']"
    refute_match(/<textarea[^>]*name="page\[body\]"/, response.body)

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
