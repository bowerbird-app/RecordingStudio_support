# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PublicSupportPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
  end

  test "logged out visitors see help sections" do
    get "/help"

    assert_response :success
    assert_flatpack_rounded_theme
    assert_includes response.body, "Hi, how can we help?"
    refute_match(/>\s*Help\s*</, response.body)
    refute_includes response.body, "Find an answer."
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Billing"
    assert_includes response.body, "Developers"
    refute_includes response.body, "How do I change my password?"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "flat-pack-page-nav"
    assert_select "[aria-label='Go back']"
    assert_select "[aria-label='Close']", count: 0
    refute_includes response.body, "flat-pack-top-nav"
    refute_includes response.body, "recording_studio_publishable/application"
    refute_includes response.body, "Sign out"
    refute_includes response.body, 'href="/users/sign_in"'
    refute_includes response.body, "Open help pages"
    refute_includes response.body, "recordable"
    assert_includes response.body, "flat_pack/application"
    assert_select "form[role='search'][class~='w-full']"
    assert_select "input[name='q'][placeholder='Search support']"
    assert_includes response.body, "max-w-none"
    assert_includes response.body, "[&amp;_input]:py-3.5"
    assert_includes response.body, "[&amp;_input]:text-base"
    assert_includes response.body, "shadow-md"
    assert_includes response.body, "fp-card-hover-strong"
    assert_includes response.body, "grid-cols-1"
    assert_select "ul[role='list']", count: 0
    refute_includes response.body, "chevron-right"
    refute_includes response.body, "badge-default-background-color"
    assert_includes response.body, "1 article"
    assert_includes response.body, "2 articles"
    refute_includes response.body, "1 page"
    refute_includes response.body, "2 pages"
    refute_includes response.body, "<span>Read</span>"
    refute_includes response.body, "<span>Open</span>"
  end

  test "logged out visitors can read a published page" do
    page = seeded_page("How do I sign in?").recordable
    path = page.published_url

    assert path.present?

    get path

    assert_response :success
    assert_flatpack_rounded_theme
    assert_includes response.body, "How do I sign in?"
    assert_select "title", text: "How do I sign in?"
    assert_select "meta[name='description']" do |nodes|
      assert_match(/Use the email and password you were given/, nodes.first["content"])
      refute_includes nodes.first["content"], "<"
      refute_includes nodes.first["content"], "<p>"
    end
    assert_select "meta[property='og:title'][content=?]", "How do I sign in?"
    assert_includes response.body, "Use the email and password you were given"
    assert_includes response.body, "Open the sign-in page"
    assert_includes response.body, "Your email"
    assert_includes response.body, "Updated"
    assert_select "h2", text: "Open the sign-in page"
    assert_select "h2", text: "Enter your details"
    assert_select "ul li", text: "Your email"
    assert_select "img[src='/how-to-sign-in.jpg'][alt='Sign-in form']"
    refute_includes response.body, "How do I change my password?"
    refute_includes response.body, "This page is live"
    refute_includes response.body, "Not live yet"
    refute_includes response.body, "Pictures"
    refute_includes response.body, "Move to trash"
    refute_includes response.body, ">Edit<"
    refute_includes response.body, "/admin/access"
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

  test "published article meta description escapes markup from the body" do
    current = seeded_page("How do I update payment details?")
    path = current.recordable.published_url
    assert path.present?

    root = RecordingStudio.root_recording_for(Workspace.find_by!(name: "Studio Workspace"))
    root.revise(current) do |page|
      page.body = "<p>Pay &amp; save the card. &lt;Keep receipts&gt;.</p>"
    end

    get path

    assert_response :success
    assert_select "title", text: "How do I update payment details?"
    assert_select "meta[name='description']" do |nodes|
      content = nodes.first["content"]
      assert_equal "Pay & save the card. <Keep receipts>.", content
    end
  end

  test "published billing article lists related pages" do
    current = seeded_page("How do I update payment details?")
    related = seeded_page("Where is my invoice?")
    path = current.recordable.published_url
    related_path = related.recordable.published_url

    assert path.present?
    assert related_path.present?

    get path

    assert_response :success
    assert_select "h1", text: "How do I update payment details?"
    assert_includes response.body, 'class="prose max-w-none'
    assert_includes response.body, "Related"
    assert_select "hr"
    assert_select "ul[role='list']"
    assert_select "a[href=?]", related_path, text: "Where is my invoice?"
  end

  test "logged out visitors cannot read a draft page" do
    recording = seeded_page("How do I change my password?")
    page = recording.recordable
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
    assert_flatpack_rounded_theme
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, ">Draft<"
    refute_includes response.body, "This page is live."
    refute_includes response.body, "Not live yet"
    assert_includes response.body, "Publish"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "/recordings/#{recording.id}/publishable/edit"
    refute_includes response.body, "recordable"
  end

  test "logged out visitors can search help sections" do
    get "/help", params: { q: "Getting started" }

    assert_response :success
    assert_select "form[role='search']"
    assert_includes response.body, "Getting started"
    refute_includes response.body, "Billing"
    assert_select "input[name='q'][value='Getting started']"
    refute_includes response.body, "Sign out"

    get "/help", params: { q: "no-such-help-section" }

    assert_response :success
    assert_includes response.body, "Nothing matches that"
    refute_includes response.body, "Getting started"
  end

  test "logged out visitors see published pages on a section and drafts stay hidden" do
    section = seeded_section("Getting started")
    slug = section.recordable.slug
    page = seeded_page("How do I sign in?").recordable
    path = page.published_url

    assert_equal "getting-started", slug
    assert path.present?

    get "/help/sections/#{slug}"

    assert_response :success
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Find answers in Getting started."
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    refute_includes response.body, "Published"
    assert_select "input[name='q'][placeholder=?]", "Search in Getting started…"
    refute_includes response.body, "[&amp;_input]:py-3.5"
    refute_includes response.body, "[&amp;_input]:text-base"
    assert_select "a[href=?]", path, text: /How do I sign in?/
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_flatpack_rounded_theme
    assert_includes response.body, "flat-pack-page-nav"
    assert_select "[aria-label='Go back']"
    assert_select "[aria-label='Close']", count: 0
    assert_includes response.body, "flat-pack-breadcrumb"
    assert_includes response.body, "flat-pack-timestamp"
    assert_select "h3", text: "How do I sign in?"
    assert_includes response.body, "grid-cols-1"
    refute_includes response.body, "Sign out"
    refute_includes response.body, 'href="/users/sign_in"'
    refute_includes response.body, "recordable"
    refute_includes response.body, "Need something else"
    refute_includes response.body, "Contact support"
    assert_select "ul[role='list']", count: 0
    refute_includes response.body, "chevron-right"
    refute_includes response.body, "<span>Read</span>"
    refute_includes response.body, "<span>Open</span>"
  end

  test "billing section shows configured subtitle snippet cards and contact when set" do
    section = seeded_section("Billing")
    payment = seeded_page("How do I update payment details?").recordable
    invoice = seeded_page("Where is my invoice?").recordable

    previous_href = RecordingStudioSupport.configuration.public_contact_href
    previous_label = RecordingStudioSupport.configuration.public_contact_label
    RecordingStudioSupport.configuration.public_contact_href = "mailto:help@example.com"
    RecordingStudioSupport.configuration.public_contact_label = "Contact support"

    get "/help/sections/#{section.recordable.slug}"

    assert_response :success
    assert_includes response.body, "Billing"
    assert_includes response.body, "Payments, invoices, and plan changes."
    assert_select "input[name='q'][placeholder=?]", "Search in Billing…"
    assert_select "a[href=?]", payment.published_url
    assert_select "a[href=?]", invoice.published_url
    assert_includes response.body, "Open billing and save the card"
    assert_includes response.body, "Open Billing, then Invoices"
    assert_includes response.body, "Need something else in Billing?"
    assert_select "a[href=?]", "mailto:help@example.com", text: "Contact support"
    refute_includes response.body, "Published"
  ensure
    RecordingStudioSupport.configuration.public_contact_href = previous_href
    RecordingStudioSupport.configuration.public_contact_label = previous_label
  end

  test "public section search with no hits shows empty state" do
    section = seeded_section("Getting started")

    get "/help/sections/#{section.recordable.slug}", params: { q: "no-such-help-page" }

    assert_response :success
    assert_includes response.body, "Nothing matches that"
    assert_includes response.body, "Try another word."
    refute_includes response.body, "How do I sign in?"
  end

  test "public section uuid bookmarks redirect to the slug url" do
    section = seeded_section("Getting started")

    get "/help/sections/#{section.id}"

    assert_response :moved_permanently
    assert_redirected_to "/help/sections/getting-started"
  end

  test "logged out visitors can read support sections without CRUD" do
    get "/support"

    assert_response :success
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Billing"
    assert_includes response.body, "Developers"
    refute_includes response.body, "New page"
    refute_includes response.body, "New section"
    refute_includes response.body, "Sign out"
    refute_includes response.body, 'href="/users/sign_in"'

    section = seeded_section("Billing")
    get "/support/sections/#{section.id}"

    assert_response :success
    assert_includes response.body, "Billing"
    refute_includes response.body, "New page"
    refute_includes response.body, "Published"
    refute_includes response.body, "How do I change my password?"
  end

  test "logged out visitors are asked to sign in for support write screens" do
    get "/support/new"

    assert_response :redirect
    assert_match "/users/sign_in", response.redirect_url
  end

end
