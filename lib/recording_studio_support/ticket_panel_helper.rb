# frozen_string_literal: true

module RecordingStudioSupport
  module TicketPanelMenu
    def support_ticket_change_button(label, ticket, changes, current:)
      render "recording_studio_support/staff_messages/ticket_menu_form",
             ticket: ticket,
             label: label,
             changes: changes,
             current: current
    end

    def support_ticket_view_users_menu_button(group_recording)
      render FlatPack::Button::DropdownItem::Component.new(
        text: support_t("messages.actions.view_users"),
        type: "button",
        data: { modal_id: support_chat_participants_modal_id(group_recording) }
      )
    end
  end

  # Included last on the message desks so these hooks win over Messages defaults.
  module TicketPanelHelper
    include TicketPanelMenu

    def messages_panel_right_header(group_recording)
      return if group_recording.blank?
      return render_support_ticket_actions(group_recording, :desktop) if support_ticket_staff_header?(group_recording)

      render_support_view_users(group_recording)
    end

    def messages_panel_right_header_mobile(group_recording)
      return unless support_ticket_staff_header?(group_recording)

      render_support_ticket_actions(group_recording, :mobile)
    end

    def messages_panel_after(group_recording)
      return if group_recording.blank?

      render "recording_studio_support/staff_messages/participants_modal", group_recording: group_recording
    end

    def messages_inbox_href(group_recording)
      return support_staff_messages_href(group_recording) if support_staff_messages_desk?

      "/recording_studio_messages/message_groups/#{group_recording.id}"
    end

    def support_ticket_actions_dom_id(group_recording, variant)
      "support-ticket-actions-#{variant}-#{group_recording.id}"
    end

    def support_ticket_strip_dom_id(ticket)
      group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
      "support-ticket-strip-#{group&.id}"
    end

    def support_chat_participants_modal_id(group_recording)
      "support-chat-participants-#{group_recording.id}"
    end

    def support_ticket_action_status_label(status)
      support_t("messages.actions.statuses.#{status}")
    end

    def support_ticket_assignee_label(assignee)
      return support_t("messages.actions.unassigned") if assignee.blank?

      message_sender_name(assignee)
    end

    def support_ticket_field_name(field, value)
      "#{support_t("messages.actions.#{field}")}, #{value}"
    end

    def support_ticket_assignee_menu_button(ticket, staff)
      value = support_ticket_assignee_value(staff)
      support_ticket_change_button(
        message_sender_name(staff),
        ticket,
        { assignee: value },
        current: support_ticket_assignee_value(ticket.assignee) == value
      )
    end

    def support_chat_participants(group_recording)
      requester = support_ticket_requester(group_recording)
      actors = Array(RecordingStudioMessages.granted_actors(group_recording))
      actors.map { |actor| [actor, support_chat_participant_kind(actor, requester)] }
            .sort_by { |_actor, role| role == :requester ? 0 : 1 }
    end

    def support_ticket_requester(group_recording)
      ticket = support_ticket_for_panel(group_recording)
      return if ticket.blank?

      recording = RecordingStudioSupport::Tickets.recording_for!(ticket)
      RecordingStudio::Event.where(recording_id: recording.id, action: "created").order(:occurred_at).first&.actor
    end

    def support_chat_participant_role(role)
      key = role == :requester ? "messages.actions.requester" : "messages.actions.staff"
      support_t(key)
    end

    private

    def render_support_ticket_actions(group_recording, variant)
      render "recording_studio_support/staff_messages/ticket_actions",
             group_recording: group_recording,
             ticket: support_ticket_for_panel(group_recording),
             variant: variant
    end

    def render_support_view_users(group_recording)
      render "recording_studio_support/staff_messages/view_users_button", group_recording: group_recording
    end

    def support_ticket_staff_header?(group_recording)
      return false if controller.is_a?(RecordingStudioSupport::UserMessagesController)
      return false unless RecordingStudioSupport::Messages.staff_actor?(current_support_actor)

      support_ticket_for_panel(group_recording).present?
    end

    def support_staff_messages_desk?
      controller.is_a?(RecordingStudioSupport::StaffMessagesController)
    end

    def support_staff_messages_href(group_recording)
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      "#{path}/messages?group_id=#{group_recording.id}"
    end

    def support_ticket_for_panel(group_recording)
      return if group_recording.blank?

      @support_tickets_for_panel ||= {}
      return @support_tickets_for_panel[group_recording.id] if @support_tickets_for_panel.key?(group_recording.id)

      @support_tickets_for_panel[group_recording.id] =
        RecordingStudioSupport::Tickets.tickets_by_group_id([group_recording.id])[group_recording.id]
    end

    # No ticket means no created event, so the role stays blank.
    def support_chat_participant_kind(actor, requester)
      return :requester if support_same_actor?(actor, requester)

      requester.present? ? :staff : nil
    end

    def support_same_actor?(left, right)
      return false if left.blank? || right.blank?

      left.instance_of?(right.class) && left.id.to_s == right.id.to_s
    end
  end
end
