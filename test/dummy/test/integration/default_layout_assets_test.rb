# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DefaultLayoutAssetsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "home uses default layout, Flatpack assets, and layout chrome after two-step sign in" do
    user = User.find_or_create_by!(email: "layout-assets@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    post new_user_session_path, params: { user: { email: user.email } }
    assert_redirected_to "#{new_user_session_path}/password"
    follow_redirect!

    assert_response :success
    assert_select "html[data-theme='rounded']"
    refute_includes response.body, "data-recording-studio-default-layout"
    assert_select "input[type='password'][name='user[password]']"
    assert_select "button[type='submit']", text: "Continue with email", count: 0
    assert_includes response.body, "flat_pack/variables"
    assert_includes response.body, "@hotwired/turbo-rails"

    post user_session_path, params: {
      user: { email: user.email, password: "Password123!" }
    }
    follow_redirect!

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "body[data-theme='rounded']"
    assert_includes response.body, "flat-pack-page-nav"
    assert_includes response.body, "flat_pack/application"
    assert_includes response.body, "flat_pack/variables"
    assert_includes response.body, "flat_pack/rich_text"
    assert_includes response.body, "/assets/tailwind"
    assert_includes response.body, "@hotwired/turbo-rails"
    refute_includes response.body, "dummy_page_nav"
    assert_includes response.body, "Sign out"
    assert_includes response.body, "/users/sign_out"
  end

  test "tailwind build includes Flatpack alert and page-nav utilities" do
    css = Rails.root.join("app/assets/builds/tailwind.css").read

    assert_includes css, "alert-success-background-color"
    assert_includes css, "alert-danger-background-color"
    assert_includes css, "button-secondary-background-color"
    assert_includes css, "button-ghost-background-color"
  end

  test "users auth sign in uses gem layout while still loading Flatpack CSS and JS" do
    get new_user_session_path

    assert_response :success
    refute_includes response.body, "data-recording-studio-default-layout"
    assert_select "html[data-theme='rounded']"
    assert_includes response.body, "flat_pack/variables"
    assert_includes response.body, "/assets/tailwind"
    assert_includes response.body, "@hotwired/turbo-rails"
    assert_includes response.body, "importmap"
    assert_select "button[type='submit']", text: "Continue with email"
    assert_select "form[action='/users/sign_in']"
    assert_select "input[type='password']", count: 0
  end
end
