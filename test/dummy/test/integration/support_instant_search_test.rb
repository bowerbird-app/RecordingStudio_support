# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportInstantSearchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
  end

  test "dummy allowlists only support pages for instant search" do
    names = Array(RecordingStudioSearch.configuration.instant_search_models)

    assert_equal ["RecordingStudioSupport::SupportPage"], names
  end

  test "public section show wires instant field and frame" do
    get "/help/sections/getting-started"

    assert_response :success
    assert_includes response.body, "recording-studio-search--instant-search"
    assert_includes response.body, "support_page_search_results"
    assert_includes response.body, "/help/sections/getting-started/instant_search"
    assert_includes response.body, "models%5B%5D=RecordingStudioSupport%3A%3ASupportPage"
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
  end

  test "public instant search finds a live article in the section" do
    get "/help/sections/getting-started/instant_search", params: {
      q: "sign in",
      models: ["RecordingStudioSupport::SupportPage"],
      frame_id: "support_page_search_results"
    }

    assert_response :success
    assert_select "turbo-frame#support_page_search_results"
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    refute_includes response.body, "Where is my invoice?"
  end

  test "public instant search empty query keeps live section articles" do
    get "/help/sections/getting-started/instant_search", params: { q: "" }

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
  end

  test "public instant search miss shows empty state" do
    get "/help/sections/getting-started/instant_search", params: { q: "no-such-help-page" }

    assert_response :success
    assert_includes response.body, "Nothing matches that"
    assert_includes response.body, "Try another keyword or"
    refute_includes response.body, "How do I sign in?"
    assert_select "a.flat-pack-link.underline[href='/help/messages']", text: "contact support", count: 1
    assert_select "a.fp-button", text: "Contact support", count: 0
    refute_includes response.body, "Need something else"
  end

  test "search engine instant hides drafts and unknown models" do
    get "/recording_studio_search/instant_search", params: {
      q: "password",
      models: ["RecordingStudioSupport::SupportPage", "User"],
      frame_id: "support_page_search_results"
    }

    assert_response :success
    refute_includes response.body, "How do I change my password?"
  end

  test "search engine instant finds a live page and ignores blank q" do
    get "/recording_studio_search/instant_search", params: {
      q: "sign in",
      models: ["RecordingStudioSupport::SupportPage"],
      frame_id: "support_page_search_results"
    }

    assert_response :success
    assert_includes response.body, "How do I sign in?"

    get "/recording_studio_search/instant_search", params: {
      q: "",
      models: ["RecordingStudioSupport::SupportPage"],
      frame_id: "support_page_search_results"
    }

    assert_response :success
    refute_includes response.body, "How do I sign in?"
  end

  test "staff instant search includes drafts in the section" do
    sign_in @user
    section = seeded_section("Getting started")

    get "/admin/support/sections/#{section.id}/instant_search", params: { q: "password" }

    assert_response :success
    assert_select "turbo-frame#support_page_search_results"
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "Where is my invoice?"
  end

  test "logged out visitors cannot use staff instant search" do
    section = seeded_section("Getting started")

    get "/admin/support/sections/#{section.id}/instant_search", params: { q: "sign" }

    assert_response :redirect
    assert_match "/users/sign_in", response.redirect_url
  end
end
