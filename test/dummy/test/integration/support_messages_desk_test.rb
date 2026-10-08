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

  test "signed in user sees ticket list without bootstrap group" do
    sign_in @patron

    assert_no_difference -> { message_group_count_for(@patron) } do
      get "/help/messages"
    end

    assert_response :success
    assert_select "h1", text: "Messages"
    assert_includes response.body, "No tickets yet"
    assert_includes response.body, "New ticket"
    assert_flatpack_rounded_theme
  end

  test "signed in user opens a ticket and can send follow up" do
    sign_in @patron

    assert_difference -> { RecordingStudioSupport::SupportTicket.count }, +1 do
      assert_difference -> { message_group_count_for(@patron) }, +1 do
        post "/help/messages", params: {
          ticket: {
            subject: "Quieter crop stuck",
            body: "The quieter crop is stuck.",
            priority: "high"
          }
        }
      end
    end

    ticket = RecordingStudioSupport::SupportTicket.order(:created_at).last
    assert_equal "Quieter crop stuck", ticket.subject
    assert_equal "high", ticket.priority
    assert_equal "open", ticket.status
    assert_redirected_to "/help/messages/#{ticket.id}"

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Quieter crop stuck"
    assert_includes response.body, "The quieter crop is stuck."
    refute_includes response.body, "+ Access"
    assert_includes response.body, "Write a message"

    group = ticket.message_group_recording
    assert_difference -> { RecordingStudioMessages.message_recordings(group).count }, +1 do
      post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
        message: { body: "Still stuck on the quieter crop." },
        return_to: "/admin/support/messages?group_id=#{group.id}"
      }
    end

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
  end

  test "opening a second ticket creates a second group" do
    sign_in @patron
    open_ticket!(@patron, subject: "First", body: "One")
    open_ticket!(@patron, subject: "Second", body: "Two")

    assert_equal 2, message_group_count_for(@patron)
    assert_equal 2, RecordingStudioSupport::Tickets.for_actor(@patron).count

    get "/help/messages"
    assert_response :success
    assert_includes response.body, "First"
    assert_includes response.body, "Second"
  end

  test "signed in user cannot open another users ticket" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Mine", body: "Private note")

    sign_out @patron
    sign_in @stranger
    get "/help/messages/#{ticket.id}"

    assert_response :forbidden
  end

  test "staff sees ticket metadata and can update status and assignee" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Need a hand with billing", body: "Need a hand with billing.")
    group = ticket.message_group_recording

    sign_out @patron
    sign_in @staff
    get "/admin/support/messages", params: { group_id: group.id }

    assert_response :success
    assert_includes response.body, "Need a hand with billing."
    assert_includes response.body, "Status"
    assert_includes response.body, "Assignee"
    assert_flatpack_rounded_theme

    patch "/admin/support/tickets/#{ticket.id}", params: {
      ticket: {
        status: "waiting_on_customer",
        assignee: "#{@staff.class.name}:#{@staff.id}"
      }
    }

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
    ticket.reload
    assert_equal "waiting_on_customer", ticket.status
    assert_equal @staff, ticket.assignee

    before = RecordingStudioMessages.message_recordings(group).count
    post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
      message: { body: "Happy to help — send the invoice number." },
      return_to: "/help/messages/#{ticket.id}"
    }
    after = RecordingStudioMessages.message_recordings(group.reload).count

    assert_equal before + 1, after
    assert_redirected_to "/help/messages/#{ticket.id}"
  end

  test "non staff cannot open staff desk" do
    sign_in @patron

    get "/admin/support/messages"

    assert_response :forbidden
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

    assert_difference -> { RecordingStudioNotifications::Notification.count }, +1 do
      assert_emails 1 do
        open_ticket!(@patron, subject: "Ping the desk", body: "Ping the desk.")
      end
    end

    notice = RecordingStudioNotifications::Notification.order(:created_at).last
    assert_equal "message_received", notice.notification_type
    assert_includes notice.url.to_s, "/admin/support/messages"
  end

  test "one to one helpers are not used on the user path" do
    source = File.read(
      RecordingStudioSupport::Engine.root.join("app/controllers/recording_studio_support/user_messages_controller.rb")
    )

    refute_includes source, "find_or_create_user_group"
    refute_includes source, "user_group_on_mount"
    refute_includes source, "create_user_group!"
    assert_includes source, "Tickets.open!"
  end

  private

  def open_ticket!(actor, subject:, body:, priority: "normal")
    RecordingStudioSupport::Tickets.open!(
      actor: actor,
      subject: subject,
      body: body,
      priority: priority
    )
  end

  def message_group_count_for(actor)
    mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: actor)
    return 0 if mount.blank?

    RecordingStudioMessages.viewable_group_recordings(
      actor: actor,
      mount_recording: mount
    ).count { |group| RecordingStudioSupport::Messages.group_owner?(group, actor) }
  end
end
