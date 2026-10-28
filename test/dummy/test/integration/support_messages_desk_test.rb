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

  test "staff sees ticket metadata and can update status and assignee" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Need a hand with billing", body: "Need a hand with billing.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

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
    assert_equal "Ticket updated.", flash[:notice]
    ticket = RecordingStudioSupport::Tickets.find!(ticket.id)
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
    sign_in @staff
    original = RecordingStudioSupport::Tickets.method(:update!)
    RecordingStudioSupport::Tickets.define_singleton_method(:update!) { |*| raise error }
    patch "/admin/support/tickets/#{ticket.id}", params: { ticket: { status: "resolved" } }

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
    assert_equal invalid.errors.full_messages.to_sentence, flash[:alert]
  ensure
    restore_tickets_method(:update!, original)
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

  test "staff header actions link rows at the support desk and list people" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Header hooks", body: "Header hooks.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    sign_out @patron
    sign_in @staff
    get "/admin/support/messages", params: { group_id: group.id }

    assert_response :success
    desk = "/admin/support/messages?group_id=#{group.id}"
    assert_select "a[href='#{desk}'][data-turbo-frame='messages-desk-panel']"
    refute_select "a[href='/recording_studio_messages/message_groups/#{group.id}']"
    assert_select "[data-flat-pack-chat-panel-part='right-header'] ##{actions_id(group, :desktop)}"
    assert_select "[data-flat-pack-chat-panel-part='right-header-mobile'] ##{actions_id(group, :mobile)}"
    assert_select "##{actions_id(group, :desktop)} [aria-current='true']", text: "Open"
    assert_select "##{actions_id(group, :mobile)} [aria-current='true']", text: "Open"
    assert_select "[data-modal-id='#{participants_id(group)}']"
    assert_select "##{participants_id(group)}", text: /#{Regexp.escape(expected_sender_name(@patron))}/
    assert_select "##{participants_id(group)}", text: /#{Regexp.escape(expected_sender_name(@staff))}/
    assert_participant_role(group, @patron, "Requester")
    assert_participant_role(group, @staff, "Support staff")
    assert_includes response.body, "Waiting on customer"
    assert_select "##{actions_id(group, :mobile)} [role='presentation']", text: "Status"
    assert_select "##{actions_id(group, :mobile)} [role='presentation']", text: "Assignee"
    assert_select "##{actions_id(group, :mobile)} [aria-current='true']", text: "Open"
    assert_select "##{strip_id(group)} select[name='ticket[status]'] option[selected][value='open']"
  end

  test "turbo stream ticket update replaces both headers and saves a new snapshot" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Stream status", body: "Stream status.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    sign_out @patron
    sign_in @staff
    assert_difference -> { RecordingStudioSupport::SupportTicket.count }, 1 do
      patch "/admin/support/tickets/#{ticket.id}",
            params: { ticket: { status: "waiting_on_customer" } },
            headers: turbo_stream_headers
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='replace'][target='#{actions_id(group, :desktop)}']"
    assert_select "turbo-stream[action='replace'][target='#{actions_id(group, :mobile)}']"
    assert_includes response.body, "Waiting on customer"
    assert_includes response.body, "Ticket updated."
    current = RecordingStudioSupport::Tickets.find!(ticket.id)
    assert_equal "waiting_on_customer", current.status
    refute_equal ticket.id, current.id
    assert_includes response.body, "/admin/support/tickets/#{current.id}"
  end

  test "turbo stream assignee update keeps the current ticket" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Stream assignee", body: "Stream assignee.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    sign_out @patron
    sign_in @staff
    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { assignee: "#{@staff.class.name}:#{@staff.id}" } },
          headers: turbo_stream_headers

    assert_response :success
    current = RecordingStudioSupport::Tickets.tickets_by_group_id([group.id])[group.id]
    assert_equal @staff, current.assignee
    assert_includes response.body, expected_sender_name(@staff)
    assert_includes response.body, actions_id(group, :desktop)
    assert_includes response.body, actions_id(group, :mobile)
  end

  test "non staff cannot patch a ticket" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Leave it", body: "Leave it.")

    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { status: "resolved" } },
          headers: turbo_stream_headers

    assert_response :forbidden
    assert_equal "open", RecordingStudioSupport::Tickets.find!(ticket.id).status
  end

  test "an invalid turbo stream update redirects with the alert" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Cannot close yet", body: "Cannot close yet.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
    invalid = RecordingStudioSupport::SupportTicket.new(subject: "")
    invalid.validate
    error = ActiveRecord::RecordInvalid.new(invalid)

    sign_out @patron
    sign_in @staff
    original = RecordingStudioSupport::Tickets.method(:update!)
    RecordingStudioSupport::Tickets.define_singleton_method(:update!) { |*| raise error }
    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { status: "resolved" } },
          headers: turbo_stream_headers

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
    assert_equal invalid.errors.full_messages.to_sentence, flash[:alert]
  ensure
    restore_tickets_method(:update!, original)
  end

  test "requester chat shows only the people button" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Just us", body: "Just us.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    get "/help/messages/#{ticket.id}"

    assert_response :success
    assert_select "[data-flat-pack-chat-panel-part='right-header'] [data-modal-id='#{participants_id(group)}']"
    assert_select "[data-flat-pack-chat-panel-part='right-header-mobile']", count: 0
    refute_includes response.body, "support-ticket-actions-"
    refute_includes response.body, "Waiting on customer"
    refute_includes response.body, "/admin/support/tickets/"
    assert_select "##{participants_id(group)}", text: /#{Regexp.escape(expected_sender_name(@patron))}/
    assert_select "##{participants_id(group)}", text: /#{Regexp.escape(expected_sender_name(@staff))}/
    assert_participant_role(group, @patron, "Requester")
    assert_participant_role(group, @staff, "Support staff")
  end

  test "a header change refreshes the strip and a later save keeps that status" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Keep the header", body: "Keep the header.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    sign_out @patron
    sign_in @staff
    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { status: "waiting_on_customer" } },
          headers: turbo_stream_headers

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='#{strip_id(group)}']"
    assert_select "##{strip_id(group)} select[name='ticket[status]'] option[selected][value='waiting_on_customer']"
    assert_select "##{strip_id(group)} form[data-turbo='false']"
    current = RecordingStudioSupport::Tickets.find!(ticket.id)

    patch "/admin/support/tickets/#{current.id}", params: {
      ticket: { status: "waiting_on_customer", assignee: "" }
    }

    assert_redirected_to "/admin/support/messages?group_id=#{group.id}"
    assert_equal "Ticket updated.", flash[:notice]
    saved = RecordingStudioSupport::Tickets.tickets_by_group_id([group.id])[group.id]
    assert_equal "waiting_on_customer", saved.status
    assert_nil saved.assignee
  end

  test "two header updates keep the latest status" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Twice", body: "Twice.")

    sign_out @patron
    sign_in @staff
    assert_difference -> { RecordingStudioSupport::SupportTicket.count }, 2 do
      patch "/admin/support/tickets/#{ticket.id}",
            params: { ticket: { status: "waiting_on_customer" } },
            headers: turbo_stream_headers
      first = RecordingStudioSupport::Tickets.find!(ticket.id)
      patch "/admin/support/tickets/#{first.id}",
            params: { ticket: { status: "waiting_on_support" } },
            headers: turbo_stream_headers
    end

    assert_response :success
    assert_equal "waiting_on_support", RecordingStudioSupport::Tickets.find!(ticket.id).status
  end

  test "unassigned clears the assignee" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Hand it back", body: "Hand it back.")
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    sign_out @patron
    sign_in @staff
    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { assignee: "#{@staff.class.name}:#{@staff.id}" } },
          headers: turbo_stream_headers
    assigned = RecordingStudioSupport::Tickets.find!(ticket.id)
    assert_equal @staff, assigned.assignee

    patch "/admin/support/tickets/#{assigned.id}",
          params: { ticket: { assignee: "" } },
          headers: turbo_stream_headers

    assert_response :success
    assert_nil RecordingStudioSupport::Tickets.tickets_by_group_id([group.id])[group.id].assignee
    assert_select "##{actions_id(group, :desktop)} [aria-current='true']", text: "Unassigned"
    assert_select "##{actions_id(group, :mobile)} [aria-current='true']", text: "Unassigned"
  end

  test "non staff html patch is forbidden" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Hands off", body: "Hands off.")

    patch "/admin/support/tickets/#{ticket.id}", params: { ticket: { status: "resolved" } }

    assert_response :forbidden
    assert_equal "open", RecordingStudioSupport::Tickets.find!(ticket.id).status
  end

  test "a logged out patch does not change the ticket" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Stay open", body: "Stay open.")
    sign_out @patron

    patch "/admin/support/tickets/#{ticket.id}", params: { ticket: { status: "resolved" } }

    assert_redirected_to new_user_session_path
    assert_equal "open", RecordingStudioSupport::Tickets.find!(ticket.id).status
  end

  test "an unknown accept type redirects after the ticket is saved" do
    sign_in @patron
    ticket = open_ticket!(@patron, subject: "Other format", body: "Other format.")

    sign_out @patron
    sign_in @staff
    patch "/admin/support/tickets/#{ticket.id}",
          params: { ticket: { status: "resolved" } },
          headers: { "Accept" => "application/json" }

    assert_redirected_to "/admin/support/messages?group_id=#{RecordingStudioSupport::Tickets.group_recording_for(ticket).id}"
    assert_equal "Ticket updated.", flash[:notice]
    assert_equal "resolved", RecordingStudioSupport::Tickets.find!(ticket.id).status
  end

  private

  def actions_id(group, variant)
    "support-ticket-actions-#{variant}-#{group.id}"
  end

  def participants_id(group)
    "support-chat-participants-#{group.id}"
  end

  def strip_id(group)
    "support-ticket-strip-#{group.id}"
  end

  def assert_participant_role(group, actor, role)
    name = expected_sender_name(actor)
    match = css_select("##{participants_id(group)} li").find { |item| item.text.include?(name) }
    assert match, "expected #{name} in the people list"
    assert_includes match.text, role
    other = role == "Requester" ? "Support staff" : "Requester"
    refute_includes match.text, other
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def expected_sender_name(actor)
    if actor.respond_to?(:display_name) && actor.display_name.present?
      actor.display_name.to_s.strip
    elsif actor.respond_to?(:name) && actor.name.present?
      actor.name.to_s.strip
    else
      actor.email.to_s.split("@").first.to_s.titleize
    end
  end

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
    mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: actor)
    return 0 if mount.blank?

    RecordingStudioMessages.viewable_group_recordings(
      actor: actor,
      mount_recording: mount
    ).count { |group| RecordingStudioSupport::Messages.group_owner?(group, actor) }
  end
end
