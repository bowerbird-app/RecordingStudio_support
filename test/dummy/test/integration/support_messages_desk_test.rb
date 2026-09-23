# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportMessagesDeskTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper

  setup do
    load Rails.root.join("db/seeds.rb")
    @staff = User.find_by!(email: "admin@admin.com")
    @staff.update!(admin: true) unless @staff.admin?

    @patron = RecordingStudioUser.create_user!(
      email: "patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @stranger = RecordingStudioUser.create_user!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Stranger",
      time_zone: "UTC"
    )
  end

  test "logged out help stays open without a composer" do
    get "/help"

    assert_response :success
    refute_includes response.body, "Write a message"
    refute_includes response.body, "flat-pack--chat-sender"
    refute_includes response.body, "messages-desk-panel"
  end

  test "logged out desks redirect to sign in" do
    get "/help/messages"

    assert_redirected_to new_user_session_path

    get "/admin/support/messages"

    assert_redirected_to new_user_session_path
  end

  test "signed in user gets one group and can send" do
    sign_in @patron

    assert_difference -> { message_group_count_for(@patron) }, +1 do
      get "/help/messages"
    end

    assert_response :success
    assert_includes response.body, "Write a message"
    assert_flatpack_rounded_theme

    group = RecordingStudioSupport::Messages.find_or_create_user_group(actor: @patron)
    assert_equal 1, message_group_count_for(@patron)

    assert_difference -> { RecordingStudioMessages.message_recordings(group).count }, +1 do
      post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
        message: { body: "The quieter crop is stuck." },
        return_to: "/admin/support/messages?group_id=#{group.id}"
      }
    end

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
  end

  test "signed in user cannot open another users group on the staff desk" do
    sign_in @patron
    get "/help/messages"
    patron_group = RecordingStudioSupport::Messages.find_or_create_user_group(actor: @patron)

    sign_out @patron
    sign_in @stranger
    get "/help/messages"
    stranger_group = RecordingStudioSupport::Messages.find_or_create_user_group(actor: @stranger)

    refute_equal patron_group.id, stranger_group.id

    get "/admin/support/messages", params: { group_id: patron_group.id }

    assert_response :forbidden
  end

  test "staff sees the thread and can reply" do
    sign_in @patron
    get "/help/messages"
    group = RecordingStudioSupport::Messages.find_or_create_user_group(actor: @patron)
    post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
      message: { body: "Need a hand with billing." },
      return_to: "/admin/support/messages?group_id=#{group.id}"
    }

    sign_out @patron
    sign_in @staff
    get "/admin/support/messages", params: { group_id: group.id }

    assert_response :success
    assert_includes response.body, "Need a hand with billing."
    assert_includes response.body, "Write a message"
    assert_flatpack_rounded_theme

    before = RecordingStudioMessages.message_recordings(group).count
    post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
      message: { body: "Happy to help — send the invoice number." },
      return_to: "/help/messages"
    }
    after = RecordingStudioMessages.message_recordings(group.reload).count

    assert_equal before + 1, after
    assert_redirected_to "/help/messages"
  end

  test "non staff cannot open staff desk" do
    sign_in @patron

    get "/admin/support/messages"

    assert_response :forbidden
  end

  test "no group when actor is nil" do
    assert_nil RecordingStudioSupport::Messages.find_or_create_user_group(actor: nil)
    assert_equal 0, RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioMessages::MessageGroup"
    ).count
  end

  test "messages admin email limits the staff set" do
    other_admin = RecordingStudioUser.create_user!(
      email: "other-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Other",
      last_name: "Admin",
      time_zone: "UTC"
    )
    other_admin.update!(admin: true)

    previous = RecordingStudioSupport.configuration.messages_admin_email
    RecordingStudioSupport.configuration.messages_admin_email = @staff.email

    begin
      assert RecordingStudioSupport::Messages.staff_actor?(@staff)
      refute RecordingStudioSupport::Messages.staff_actor?(other_admin)

      sign_in other_admin
      get "/admin/support/messages"

      assert_response :forbidden
    ensure
      RecordingStudioSupport.configuration.messages_admin_email = previous
    end
  end

  test "public contact href defaults to help messages" do
    assert_equal "/help/messages", RecordingStudioSupport.configuration.public_contact_href

    section = seeded_section("Getting started")
    get "/help/sections/#{section.recordable.slug}"

    assert_response :success
    assert_select "a[href='/help/messages']", text: /Contact support/
  end

  test "send notifies staff in app and by email" do
    sign_in @patron
    get "/help/messages"
    group = RecordingStudioSupport::Messages.find_or_create_user_group(actor: @patron)

    assert_difference -> { RecordingStudioNotifications::Notification.count }, +1 do
      assert_emails 1 do
        post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
          message: { body: "Ping the desk." },
          return_to: "/admin/support/messages?group_id=#{group.id}"
        }
      end
    end

    notice = RecordingStudioNotifications::Notification.order(:created_at).last
    assert_equal "message_received", notice.notification_type
    assert_includes notice.url.to_s, "/admin/support/messages"
  end

  private

  def message_group_count_for(actor)
    mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: actor)
    return 0 if mount.blank?

    RecordingStudioMessages.viewable_group_recordings(
      actor: actor,
      mount_recording: mount
    ).count { |group| RecordingStudioSupport::Messages.group_owner?(group, actor) }
  end
end
