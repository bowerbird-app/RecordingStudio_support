# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PublicSupportPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
  end

  test "logged out visitors see only indexable help pages" do
    get "/help"

    assert_response :success
    assert_select "body[data-theme='rounded']"
    assert_includes response.body, "Help"
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "flat-pack-page-nav"
    assert_select "[aria-label='Go back']"
    assert_select "[aria-label='Close']"
    refute_includes response.body, "flat-pack-top-nav"
    refute_includes response.body, "recording_studio_publishable/application"
    refute_includes response.body, "Sign out"
    refute_includes response.body, 'href="/users/sign_in"'
    refute_includes response.body, "Open help pages"
    refute_includes response.body, "recordable"
    assert_includes response.body, "flat_pack/application"
    assert_select "form[role='search'][class~='w-full']"
    assert_select "input[name='q']"
    assert_includes response.body, "max-w-none"
  end

  test "logged out visitors can read a published page" do
    page = RecordingStudioSupport::SupportPage.find_by!(title: "How do I sign in?")
    path = page.published_url

    assert path.present?

    get path

    assert_response :success
    assert_select "body[data-theme='rounded']"
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "Use the email and password you were given"
    assert_includes response.body, "Updated"
    refute_includes response.body, "How do I change my password?"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "flat-pack-page-nav"
    assert_select "[aria-label='Go back']"
    assert_select "[aria-label='Close']"
    refute_includes response.body, "flat-pack-top-nav"
    refute_includes response.body, "recording_studio_publishable/application"
    refute_includes response.body, "Sign out"
    refute_includes response.body, 'href="/users/sign_in"'
    refute_includes response.body, "Open help pages"
    refute_includes response.body, "recordable"
  end

  test "logged out visitors cannot read a draft page" do
    page = RecordingStudioSupport::SupportPage.find_by!(title: "How do I change my password?")
    recording = RecordingStudioSupport::Pages.recording_for(page)
    publishable_recording = recording.publishable_child_recording

    assert publishable_recording
    refute page.indexable?

    get "/help/#{publishable_recording.id}/how-do-i-change-my-password"

    assert_response :not_found
  end

  test "signed in owner can preview a draft on the authenticated show" do
    sign_in @user
    recording = seeded_page("How do I change my password?")

    get "/support/#{recording.id}"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "body[data-theme='rounded']"
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, "Not live yet. This preview is just for you."
    assert_includes response.body, "Publish"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "/recordings/#{recording.id}/publishable/edit"
    refute_includes response.body, "recordable"
  end

  test "logged out visitors can search indexable help pages" do
    get "/help", params: { q: "sign in" }

    assert_response :success
    assert_select "form[role='search']"
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    assert_select "input[name='q'][value='sign in']"
    refute_includes response.body, "Sign out"

    get "/help", params: { q: "no-such-help-page" }

    assert_response :success
    assert_includes response.body, "Nothing matches that"
    refute_includes response.body, "How do I sign in?"
  end

  test "logged out visitors are asked to sign in for authenticated help" do
    get "/support"

    assert_response :redirect
    assert_match "/users/sign_in", response.redirect_url
  end

  private

  def seeded_page(title)
    RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioSupport::SupportPage",
      trashed_at: nil
    ).find { |recording| recording.recordable.title == title }
  end
end
