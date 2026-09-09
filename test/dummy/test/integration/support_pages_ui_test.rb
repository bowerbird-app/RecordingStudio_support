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

  test "index lists seeded help sections with default layout chrome" do
    get "/support"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Billing"
    assert_includes response.body, "Developers"
    assert_includes response.body, "New page"
    assert_includes response.body, "New section"
    assert_includes response.body, 'href="/support/new"'
    assert_includes response.body, 'href="/support/sections/new"'
    refute_includes response.body, "How do I change my password?"
    assert_includes response.body, "flat-pack-page-nav"
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "flat_pack/application"
    assert_flatpack_rounded_theme
    assert_select "a[aria-label='Close'][href='/']"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "/users/sign_out"
    refute_includes response.body, "recordable"
    refute_includes response.body, "This app proves the support gem"
    assert_select "form[role='search'][class~='w-full']"
    assert_select "input[name='q'][placeholder='Search support']"
    assert_includes response.body, "Find an answer."
    assert_includes response.body, "max-w-none"
    assert_includes response.body, "card-border-color"
    assert_select "ul[role='list']"
    assert_select "li[role='listitem']"
    assert_includes response.body, "chevron-right"
    assert_select "[class*='badge-default-background-color']", text: "1", count: 2
    assert_select "[class*='badge-default-background-color']", text: "2", count: 1
    refute_includes response.body, "1 page"
    refute_includes response.body, "2 pages"
    refute_includes response.body, "<span>Open</span>"
    refute_includes response.body, "<span>Read</span>"
  end

  test "index ILIKE search matches section titles" do
    get "/support", params: { q: "Getting started" }

    assert_response :success
    assert_flatpack_rounded_theme
    assert_select "form[role='search']"
    assert_includes response.body, "Getting started"
    refute_includes response.body, "Billing"
    assert_select "input[name='q'][value='Getting started']"
  end

  test "index search empty state is human" do
    get "/support", params: { q: "no-such-help-section" }

    assert_response :success
    assert_includes response.body, "Nothing matches that"
    assert_includes response.body, "Try another word."
    refute_includes response.body, "Getting started"
    refute_includes response.body, "recordable"
  end

  test "section show lists pages in that section" do
    section = seeded_section("Getting started")

    get "/support/sections/#{section.id}"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I update payment details?"
    assert_includes response.body, "Published"
    assert_includes response.body, "Draft"
    assert_includes response.body, "New page"
    assert_includes response.body, "href=\"/support/new?section_id=#{section.id}\""
    assert_includes response.body, "href=\"/support/#{seeded_page('How do I change my password?').id}\""
    refute_includes response.body, "recordable"
    assert_includes response.body, "card-border-color"
    assert_select "ul[role='list']"
    assert_includes response.body, "chevron-right"
    refute_includes response.body, "<span>Open</span>"
    refute_includes response.body, "<span>Read</span>"
  end

  test "owner preview has no edit button or form" do
    recording = seeded_page("How do I change my password?")

    get "/support/#{recording.id}"

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, ">Draft<"
    refute_includes response.body, "This page is live."
    refute_includes response.body, "Not live yet"
    refute_includes response.body, "Edit page"
    refute_includes response.body, "href=\"/support/#{recording.id}/edit\""
    refute_match(/<a[^>]*>\s*Edit\s*<\/a>/, response.body)
    refute_select "input[name='page[title]']"
    refute_includes response.body, "flat-pack-richtext-wrapper"
  end

  test "show renders title, body, and inline image" do
    recording = seeded_page("How do I sign in?")

    get "/support/#{recording.id}"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "Use the email and password you were given"
    assert_includes response.body, "Open the sign-in page"
    assert_includes response.body, "Your email"
    assert_select "img[src='/how-to-sign-in.jpg'][alt='Sign-in form']"
    refute_includes response.body, "Pictures"
    close = css_select("a[aria-label='Close']").first
    assert close
    assert_match(%r{\A/support/?\z}, close["href"])
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Studio Workspace"
    refute_includes response.body, ">Edit<"
    refute_includes response.body, "href=\"/support/#{recording.id}/edit\""
    refute_includes response.body, "Edit page"
    assert_includes response.body, "Publish"
    assert_includes response.body, ">Live<"
    refute_includes response.body, "This page is live."
    refute_includes response.body, "View now"
    refute_includes response.body, "Open live page"
    assert_includes response.body, 'aria-label="Move to trash"'
    refute_match(/>\s*Move to trash\s*</, response.body)
    assert RecordingStudioSupport::PageView.exists?(recording_id: recording.id)
  end

  test "show renders sanitized HTML and keeps inline images" do
    recording = RecordingStudioSupport::Pages.create!(
      parent_recording: seeded_section("Getting started"),
      title: "Printer jam",
      body: "<p>Turn it off.</p><h2>Then on</h2><img src=\"https://example.test/x.png\" alt=\"nope\">",
      actor: @user
    )

    get "/support/#{recording.id}"

    assert_response :success
    assert_select "p", text: "Turn it off."
    assert_select "h2", text: "Then on"
    refute_includes response.body, "&lt;p&gt;"
    assert_select "img[alt='nope']"
  end

  test "new and create go through public record helper" do
    get "/support/new"

    assert_response :success
    assert_includes response.body, "New page"
    assert_select "input[name='page[title]']"
    assert_includes response.body, "page[section_id]"
    assert_select "input[type='hidden'][name='page[body]']"
    assert_includes response.body, "flat-pack-richtext-wrapper"
    assert_includes response.body, "flat-pack--tiptap"
    assert_includes response.body, "/support/uploads"
    assert_includes response.body, "Save"
    assert_includes response.body, "Cancel"
    refute_includes response.body, "Words only"
    refute_includes response.body, "Pictures live under the page"

    assert_difference -> { RecordingStudioSupport::SupportPage.count }, 1 do
      post "/support", params: {
        page: {
          section_id: seeded_section("Getting started").id,
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
    assert_includes response.body, "/support/uploads"
    assert_includes response.body, "Save"
    assert_includes response.body, "Cancel"
    refute_includes response.body, "flat-pack-button-group"
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

  test "owner can upload an image for the body editor" do
    file = Rack::Test::UploadedFile.new(
      Rails.root.join("public/how-to-sign-in.jpg"),
      "image/jpeg"
    )

    post "/support/uploads", params: { file: file }

    assert_response :created
    payload = response.parsed_body
    assert payload["url"].present?
    assert_match(%r{\A/rails/active_storage/}, payload["url"])
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
    assert_includes response.body, "Getting started"
    refute_includes response.body, "New page"
    refute_includes response.body, "New section"

    get "/support/sections/#{seeded_section('Getting started').id}"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    refute_includes response.body, "New page"

    recording = seeded_page("How do I change my password?")
    get "/support/#{recording.id}/edit"
    assert_redirected_to "/support/#{recording.id}"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "Edit page"

    get "/support/new"

    assert_response :forbidden
  end

  test "viewer without access can still read public support lists" do
    stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in stranger

    get "/support"

    assert_response :success
    assert_includes response.body, "Getting started"
    refute_includes response.body, "New page"
    refute_includes response.body, "New section"

    get "/support/sections/#{seeded_section('Getting started').id}"

    assert_response :success
    refute_includes response.body, "New page"

    get "/support/new"

    assert_response :forbidden
  end

  test "trash uses the trashable helper and leaves the index" do
    recording = seeded_page("How do I change my password?")

    post "/support/#{recording.id}/trash"

    assert_response :redirect
    assert_match(%r{/support/?\z}, response.redirect_url)
    assert recording.reload.trashed_at
    get "/support/sections/#{seeded_section('Getting started').id}"
    refute_includes response.body, "How do I change my password?"
  end

  test "editor of one workspace cannot edit another workspace page by id" do
    editor = User.create!(
      email: "editor-a-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace_a = Workspace.create!(name: "Workspace A #{SecureRandom.hex(4)}")
    workspace_b = Workspace.create!(name: "Workspace B #{SecureRandom.hex(4)}")
    root_a = RecordingStudio.root_recording_for(workspace_a)
    root_b = RecordingStudio.root_recording_for(workspace_b)
    grant_role!(root_a, editor, :edit)
    grant_role!(root_b, editor, :view)

    section_b = record_support_section(root_b, title: "B only section")
    page_b = record_support_page(root_b, section_b, title: "B only page")
    section_a = record_support_section(root_a, title: "A section")
    page_a = record_support_page(root_a, section_a, title: "A page")

    sign_in editor
    switch_to_root!(root_b)

    get "/support/#{page_b.id}/edit"
    assert_redirected_to "/support/#{page_b.id}"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "B only page"
    refute_includes response.body, "Edit page"

    get "/support/#{page_a.id}/edit"
    assert_response :success
    assert_includes response.body, "Edit page"

    patch "/support/#{page_b.id}", params: { page: { title: "Hijacked", body: "Nope" } }
    assert_redirected_to "/support/#{page_b.id}"
    assert_equal "B only page", page_b.reload.recordable.title

    post "/support/#{page_b.id}/trash"
    assert_response :forbidden
    assert_nil page_b.reload.trashed_at

    get "/support/new", params: { section_id: section_b.id }
    assert_response :forbidden

    post "/support", params: {
      page: { title: "Smuggled", body: "Nope", section_id: section_b.id }
    }
    assert_response :forbidden
    titles = RecordingStudio::Recording.where(
      parent_recording_id: section_b.id,
      recordable_type: "RecordingStudioSupport::SupportPage",
      trashed_at: nil
    ).filter_map { |recording| recording.recordable&.title }
    refute_includes titles, "Smuggled"
  end

  test "editor of one workspace cannot revise or trash another workspace section" do
    editor = User.create!(
      email: "section-editor-a-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace_a = Workspace.create!(name: "Section A #{SecureRandom.hex(4)}")
    workspace_b = Workspace.create!(name: "Section B #{SecureRandom.hex(4)}")
    root_a = RecordingStudio.root_recording_for(workspace_a)
    root_b = RecordingStudio.root_recording_for(workspace_b)
    grant_role!(root_a, editor, :edit)
    grant_role!(root_b, editor, :view)

    section_b = record_support_section(root_b, title: "Keep my name")

    sign_in editor
    switch_to_root!(root_b)

    get "/support/sections/#{section_b.id}/edit"
    assert_redirected_to "/support/sections/#{section_b.id}"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Keep my name"
    refute_includes response.body, "Edit section"

    patch "/support/sections/#{section_b.id}", params: { section: { title: "Renamed" } }
    assert_redirected_to "/support/sections/#{section_b.id}"
    assert_equal "Keep my name", section_b.reload.recordable.title

    post "/support/sections/#{section_b.id}/trash"
    assert_response :forbidden
    assert_nil section_b.reload.trashed_at
  end

  test "public help article shows section badge and home without related pages" do
    current = seeded_page("How do I update payment details?")
    related = seeded_page("Where is my invoice?")
    current_path = current.recordable.published_url
    related_path = related.recordable.published_url

    assert current_path.present?
    assert related_path.present?

    get current_path

    assert_response :success
    assert_select "h1", text: "How do I update payment details?"
    assert_includes response.body, 'class="mt-8 prose max-w-none'
    assert_includes response.body, 'class="w-fit"'
    assert_match(/\bUpdated [A-Z][a-z]+ \d{1,2}, \d{4}\b/, response.body)
    refute_match(/\bago\b/, response.body)
    assert_select "a[aria-label='Home'][href='/help']"
    refute_includes response.body, "Related"
    assert_select "a[href=?]", related_path, count: 0
  end

  private

  def switch_to_root!(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/support"
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
