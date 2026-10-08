# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CustomerI18nTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
  end

  test "language selector sits in the dummy top nav" do
    get "/help"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    assert_select ".dummy-language-selector"
    assert_select "nav.flat-pack-page-nav .dummy-language-selector"
  end

  test "help home article and messages stay English until the host locale changes" do
    get "/help"

    assert_response :success
    assert_includes response.body, "Hi, how can we help?"
    assert_select "input[name='q'][placeholder='Search support']"
    assert_includes response.body, "1 article"
    assert_select "html[lang='en']"

    page = seeded_page("How do I sign in?").recordable
    get page.published_url

    assert_response :success
    assert_match(/\bUpdated [A-Z][a-z]+ \d{1,2}, \d{4}\b/, response.body)
    assert_select "a[aria-label='Home'][href='/help']"
    assert_select "a[href='/help/messages']", text: "Contact support"

    sign_in @user
    get "/help/messages"

    assert_response :success
    assert_select "h1", text: "Messages"
    assert_includes response.body, "Write to support when Help"
  end

  test "dummy French locale renders help home an article and messages" do
    switch_to_french

    get "/help"

    assert_response :success
    assert_select "html[lang='fr']"
    assert_includes response.body, "Salut, comment peut-on aider ?"
    assert_select "input[name='q'][placeholder='Rechercher dans l’aide']"
    assert_includes response.body, "1 article"
    refute_includes response.body, "Hi, how can we help?"
    refute_includes response.body, "Search support"

    page = seeded_page("How do I sign in?").recordable
    get page.published_url

    assert_response :success
    assert_includes response.body, "Mis à jour le"
    assert_select "a[aria-label='Accueil'][href='/help']"
    assert_select "a[href='/help/messages']", text: "Contacter l’assistance"
    refute_includes response.body, "Updated "
    refute_includes response.body, "Contact support"

    sign_in @user
    get "/help/messages"

    assert_response :success
    assert_select "h1", text: "Messages"
    assert_includes response.body, "Écrivez à l’assistance quand l’aide ne suffit pas."
    refute_includes response.body, "Write to support when Help"
  end

  test "config and helper text overrides still win" do
    previous_title = RecordingStudioSupport.configuration.public_help_title
    previous_label = RecordingStudioSupport.configuration.public_contact_label
    RecordingStudioSupport.configuration.public_help_title = "Acme help"
    RecordingStudioSupport.configuration.public_contact_label = "Email us"

    get "/help"

    assert_response :success
    assert_includes response.body, "Acme help"
    refute_includes response.body, "Hi, how can we help?"

    get "/help/sections/getting-started"

    assert_response :success
    assert_select "a[href='/help/messages']", text: "Email us"
  ensure
    RecordingStudioSupport.configuration.public_help_title = previous_title
    RecordingStudioSupport.configuration.public_contact_label = previous_label
  end

  private

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/help" }
    follow_redirect!
  end
end
