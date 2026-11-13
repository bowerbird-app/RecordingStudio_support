# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportInboxTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper

  setup do
    load Rails.root.join("db/seeds.rb")
    @support_user = User.find_by!(email: "admin@admin.com")
    @support_user.update!(admin: true) unless @support_user.admin?

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

  test "logged out inboxes redirect to sign in" do
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

    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
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

  test "support team sees ticket controls in the thread header and can update status" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Need a hand with billing", body: "Need a hand with billing.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
    recording_id = RecordingStudioSupport::Tickets.recording_for!(ticket).id

    sign_out @patron
    sign_in @support_user
    get "/admin/support/messages", params: { group_id: group.id }

    assert_response :success
    assert_includes response.body, "Need a hand with billing."
    assert_select "#support-ticket-controls-#{recording_id}"
    assert_select "#support-ticket-controls-mobile-#{recording_id}"
    assert_select '[data-flat-pack-chat-panel-part="right-header"] #support-ticket-controls-%s' % recording_id
    assert_select '[data-flat-pack-chat-panel-part="right-header"] .fp-button-dropdown'
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"] #support-ticket-controls-mobile-%s' % recording_id
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"] .fp-button-dropdown'
    refute_select '[data-flat-pack-chat-panel-part="right-header"] .w-56'
    refute_select '[data-flat-pack-chat-panel-part="right-header-mobile"] .w-24'
    assert_select "#support-ticket-status-#{ticket.id}[data-fp-style='default']", text: /Open/
    assert_select "#support-ticket-mobile-status-#{ticket.id}[data-fp-style='default']", text: /Open/
    assert_select "#support-ticket-controls-#{recording_id} [role='menuitem']", text: "Open"
    assert_select "#support-ticket-controls-#{recording_id} [role='menuitem']", text: "Resolved"
    refute_includes response.body, "Waiting on customer"
    refute_includes response.body, "waiting_on_customer"
    refute_includes response.body, "waiting_on_support"
    assert_select "#support-ticket-controls-#{recording_id} form[data-turbo-stream='true'] input[name='ticket[status]'][value='resolved']"
    refute_select "#support-ticket-controls-#{recording_id} label"
    refute_select "#support-ticket-controls-mobile-#{recording_id} label"
    refute_select "#support-ticket-controls-#{recording_id} select"
    refute_select ".flex.w-full.flex-col.gap-4 > form"
    assert_flatpack_rounded_theme

    patch "/admin/support/tickets/#{ticket.id}", params: {
      ticket: { status: "resolved" }
    }

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
    ticket = RecordingStudioSupport::Tickets.find!(ticket.id)
    assert_equal "resolved", ticket.status
    assert_not_nil ticket.resolved_at

    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { status: "open" } },
          as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    ticket = RecordingStudioSupport::Tickets.find!(ticket.id)
    assert_equal "open", ticket.status
    assert_nil ticket.resolved_at
    assert_includes response.body, "support-ticket-controls-#{recording_id}"
    assert_includes response.body, "support-ticket-controls-mobile-#{recording_id}"

    before = RecordingStudioMessages.message_recordings(group).count
    post "/recording_studio_messages/message_groups/#{group.id}/messages", params: {
      message: { body: "Happy to help — send the invoice number." },
      return_to: "/help/messages/#{ticket.id}"
    }
    after = RecordingStudioMessages.message_recordings(group.reload).count

    assert_equal before + 1, after
    assert_redirected_to "/help/messages/#{ticket.id}"
  end

  test "opening a ticket on a group that already has one shows the error" do
    sign_in @patron
    error = RecordingStudioSupport::Tickets::AlreadyExists.new
    original = RecordingStudioSupport::Tickets.method(:open!)
    RecordingStudioSupport::Tickets.define_singleton_method(:open!) { |*| raise error }
    post "/help/messages", params: {
      ticket: { subject: "Again", body: "This thread already has one.", priority: "normal" }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "This conversation already has a ticket."
  ensure
    restore_tickets_method(:open!, original)
  end

  test "a failed ticket update reports the invalid record" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Cannot close yet", body: "Cannot close yet.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
    invalid = RecordingStudioSupport::SupportTicket.new(subject: "")
    invalid.validate
    error = ActiveRecord::RecordInvalid.new(invalid)

    sign_out @patron
    sign_in @support_user
    original = RecordingStudioSupport::Tickets.method(:update!)
    RecordingStudioSupport::Tickets.define_singleton_method(:update!) { |*| raise error }
    patch "/admin/support/tickets/#{ticket.id}", params: { ticket: { status: "resolved" } }

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
    assert_equal invalid.errors.full_messages.to_sentence, flash[:alert]
  ensure
    restore_tickets_method(:update!, original)
  end

  test "customer thread does not show support ticket controls" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Mine", body: "Private note")
    recording_id = RecordingStudioSupport::Tickets.recording_for!(ticket).id

    get "/help/messages/#{ticket.id}"

    assert_response :success
    assert_select "#support-ticket-controls-#{recording_id}", count: 0
    refute_includes response.body, "ticket[status]"
  end

  test "untagged support group does not show support ticket controls" do
    sign_in @support_user
    mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: @support_user)
    group = RecordingStudioMessages.create_group(mount, title: "Not a ticket", actor: @support_user)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "This is not a ticket thread.",
      actor: @support_user
    )

    get "/recording_studio_messages/message_groups/#{group.id}",
        headers: { "Turbo-Frame" => "messages-desk-panel" }

    assert_response :success
    assert_includes response.body, "Not a ticket"
    assert_select "[id^='support-ticket-controls']", count: 0
    refute_includes response.body, "ticket[status]"
  end

  test "someone outside the support team cannot open support inbox" do
    sign_in @patron

    get "/admin/support/messages"

    assert_response :forbidden
  end

  test "support screens use Accessible edit on the support center" do
    other = RecordingStudioUser.create_user!(
      email: "other-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Other",
      last_name: "Admin",
      time_zone: "UTC"
    )
    other.update!(admin: true) if other.respond_to?(:admin=)

    assert RecordingStudioSupport::Messages.support_team_actor?(@support_user)
    refute RecordingStudioSupport::Messages.support_team_actor?(other)

    sign_in other
    get "/admin/support/messages"

    assert_response :forbidden
  end

  test "public contact href defaults to help messages" do
    assert_equal "/help/messages", RecordingStudioSupport.configuration.public_contact_href

    section = seeded_section("Getting started")
    get "/help/sections/#{section.recordable.slug}"

    assert_response :success
    assert_select "a[href='/help/messages']", text: /Contact support/
  end

  test "a customer reply notifies a support admin with only inherited access" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Ping the inbox", body: "Ping the inbox.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    assert_empty direct_access_roles(group, @support_user)
    assert RecordingStudioAccessible.authorized?(actor: @support_user, recording: group, role: :view)

    assert_difference -> { message_received_for(@support_user).count }, +1 do
      assert_no_difference -> { message_received_for(@patron).count } do
        assert_emails 1 do
          RecordingStudioMessages.send_message(
            group_recording: group,
            body: "Still stuck on the quieter crop.",
            actor: @patron
          )
        end
      end
    end

    notice = message_received_for(@support_user).order(:created_at).last
    assert_equal "message_received", notice.notification_type
    assert_equal @support_user, notice.recipient
    assert_empty direct_access_roles(group.reload, @support_user)
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

  def restore_tickets_method(name, original)
    return unless original

    RecordingStudioSupport::Tickets.define_singleton_method(name) do |*args, **kwargs, &block|
      original.call(*args, **kwargs, &block)
    end
  end

  def open_ticket!(actor, subject:, body:, priority: "normal")
    RecordingStudioSupport::Tickets.open!(
      actor: actor,
      subject: subject,
      body: body,
      priority: priority
    )
  end

  def message_group_count_for(actor)
    RecordingStudioSupport::Tickets.for_actor(actor).count
  end

  def message_received_for(actor)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: actor
    )
  end
end
