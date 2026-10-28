# frozen_string_literal: true

module RecordingStudioSupport
  module TicketPanelMenu
    def support_ticket_change_button(label, ticket, changes, current:)
      button_to(label, staff_ticket_update_path_for(ticket), support_ticket_change_options(changes, current: current))
    end

    def support_ticket_view_users_menu_button(group_recording)
      button_tag(
        support_t("messages.actions.view_users"),
        type: "button",
        class: support_ticket_menu_button_class(current: false),
        role: "menuitem",
        data: { modal_id: support_chat_participants_modal_id(group_recording) }
      )
    end

    def support_ticket_menu_button_class(current:)
      token = [
        "flex w-full cursor-pointer items-center gap-[var(--dropdown-item-gap)]",
        "rounded-[var(--dropdown-item-radius)] px-[var(--dropdown-item-padding-x)]",
        "py-[var(--dropdown-item-padding-y)] text-left text-sm text-[var(--surface-content-color)]",
        "hover:bg-[var(--surface-muted-background-color)]"
      ].join(" ")
      return token unless current

      "#{token} bg-[var(--surface-muted-background-color)] font-semibold"
    end

    private

    def support_ticket_change_options(changes, current:)
      options = {
        method: :patch,
        params: { ticket: changes },
        form: { class: "block w-full", data: { turbo_stream: true, turbo_frame: "_top" } },
        class: support_ticket_menu_button_class(current: current),
        role: "menuitem"
      }
      options[:aria] = { current: "true" } if current
      options
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
      actors = RecordingStudioMessages.granted_actors(group_recording)
      owners, others = actors.partition do |actor|
        RecordingStudioSupport::Messages.group_owner?(group_recording, actor)
      end
      owners.map { |actor| [actor, :requester] } + others.map { |actor| [actor, :staff] }
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

      RecordingStudioSupport::Tickets.tickets_by_group_id([group_recording.id])[group_recording.id]
    end
  end
end
