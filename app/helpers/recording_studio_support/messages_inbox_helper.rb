# frozen_string_literal: true

module RecordingStudioSupport
  module MessagesInboxHelper # rubocop:disable Metrics/ModuleLength -- inbox paths and ticket header hooks stay together
    STATUS_MENU_ITEM_CLASSES = [
      "flex items-center gap-[var(--dropdown-item-gap)]",
      "w-full",
      "px-[var(--dropdown-item-padding-x)] py-[var(--dropdown-item-padding-y)]",
      "text-sm text-left",
      "rounded-[var(--dropdown-item-radius)]",
      "text-[var(--surface-content-color)]",
      "hover:bg-[var(--surface-muted-background-color)]",
      "cursor-pointer",
      "transition-colors duration-base",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
    ].join(" ").freeze

    def support_messages_form_url(group_recording)
      return if group_recording.blank?

      "/recording_studio_messages/message_groups/#{group_recording.id}/messages"
    end

    def messages_inbox_href(group_recording, inbox: nil)
      return my_messages_href(group_recording) if inbox == :my_messages && respond_to?(:my_messages_href)
      return staff_inbox_group_href(group_recording) if staff_inbox_request?

      ticket = RecordingStudioSupport::Tickets.tickets_by_group_id([group_recording.id])[group_recording.id]
      return help_message_path_for(ticket) if ticket

      "/recording_studio_messages/message_groups/#{group_recording.id}"
    end

    def message_sender_name(actor)
      return Copy.t("messages.someone") if actor.blank?

      actor_display_name(actor) || actor_email_label(actor) || actor.class.name.demodulize
    end

    def actor_display_name(actor)
      return actor.display_name.to_s.strip if actor.respond_to?(:display_name) && actor.display_name.present?
      return actor.name.to_s.strip if actor.respond_to?(:name) && actor.name.present?

      nil
    end

    def actor_email_label(actor)
      return unless actor.respond_to?(:email) && actor.email.present?

      actor.email.to_s.split("@").first.to_s.titleize
    end

    def help_messages_path_for
      public_path = RecordingStudioSupport.configuration.public_pages_path.to_s.chomp("/")
      "#{public_path}/messages"
    end

    def new_help_message_path_for
      "#{help_messages_path_for}/new"
    end

    def help_message_path_for(ticket)
      "#{help_messages_path_for}/#{ticket.id}"
    end

    def staff_ticket_update_path_for(ticket)
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      "#{path}/tickets/#{ticket.id}"
    end

    def support_ticket_status_label(ticket)
      key = "messages.statuses.#{ticket.status}"
      return Copy.t(key) if I18n.exists?("recording_studio.support.#{key}")

      ticket.status.to_s.humanize
    end

    def support_ticket_priority_label(priority)
      key = "messages.priorities.#{priority}"
      return Copy.t(key) if I18n.exists?("recording_studio.support.#{key}")

      priority.to_s.humanize
    end

    def support_ticket_status_badge(ticket)
      style = ticket.status.to_s == "resolved" ? :success : :info
      render FlatPack::Badge::Component.new(
        text: support_ticket_status_label(ticket),
        style: style,
        size: :xs
      )
    end

    def support_ticket_status_options
      SupportTicket::STATUSES.map { |status| [support_ticket_status_label_for(status), status] }
    end

    def support_ticket_status_action(ticket, label:, status:)
      button_to(
        label,
        staff_ticket_update_path_for(ticket),
        method: :patch,
        params: { ticket: { status: status } },
        form: { class: "w-full", data: { turbo: true, turbo_stream: true } },
        class: STATUS_MENU_ITEM_CLASSES,
        role: "menuitem"
      )
    end

    def support_ticket_status_label_for(status)
      {
        "open" => "Open",
        "resolved" => "Resolved"
      }.fetch(status.to_s, status.to_s.humanize)
    end

    def support_ticket_priority_options
      SupportTicket::PRIORITIES.map { |priority| [support_ticket_priority_label(priority), priority] }
    end

    def messages_panel_right_header(group_recording, actor:, mount:)
      render_support_ticket_controls(group_recording, actor: actor, mount: mount, mobile: false)
    end

    def messages_panel_right_header_mobile(group_recording, actor:, mount:)
      render_support_ticket_controls(group_recording, actor: actor, mount: mount, mobile: true)
    end

    def staff_support_ticket_for_header(group_recording, actor:, mount:)
      return if group_recording.blank? || actor.blank? || mount.blank?
      return unless mount.recordable&.key.to_s == RecordingStudioSupport::Messages::SUPPORT_MOUNT_KEY.to_s
      return unless RecordingStudioSupport::Messages.staff_actor?(actor)

      RecordingStudioSupport::Tickets.tickets_by_group_id([group_recording.id])[group_recording.id]
    end

    def support_ticket_controls_id(ticket, mobile: false)
      recording_id = RecordingStudioSupport::Tickets.recording_for!(ticket).id
      mobile ? "support-ticket-controls-mobile-#{recording_id}" : "support-ticket-controls-#{recording_id}"
    end

    private

    def staff_inbox_request?
      staff_path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      request.path.to_s.start_with?(staff_path)
    end

    def staff_inbox_group_href(group_recording)
      "#{RecordingStudioSupport.configuration.pages_path.to_s.chomp('/')}/messages?group_id=#{group_recording.id}"
    end

    def render_support_ticket_controls(group_recording, actor:, mount:, mobile:)
      ticket = staff_support_ticket_for_header(group_recording, actor: actor, mount: mount)
      return if ticket.blank?

      render "recording_studio_support/staff_messages/ticket_controls",
             ticket: ticket,
             mobile: mobile
    end
  end
end
