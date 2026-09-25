# frozen_string_literal: true

module RecordingStudioSupport
  module MessagesDeskHelper
    # Staff desk is mounted under /admin/support. Engine URL helpers can pick up
    # SCRIPT_NAME=/admin and generate /admin/recording_studio_messages/..., which
    # 404s. Always address the Messages mount from the app root.
    def support_messages_form_url(group_recording)
      return if group_recording.blank?

      "/recording_studio_messages/message_groups/#{group_recording.id}/messages"
    end

    def messages_inbox_href(group_recording)
      "/recording_studio_messages/message_groups/#{group_recording.id}"
    end

    # Prefer profile/display names so sidebar snippets say "Avery Admin: …"
    # instead of the email local-part ("Admin: …").
    def message_sender_name(actor)
      return "Someone" if actor.blank?

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

    def help_messages_path_for_desk
      public_path = RecordingStudioSupport.configuration.public_pages_path.to_s.chomp("/")
      "#{public_path}/messages"
    end

    def new_help_message_path_for_desk
      "#{help_messages_path_for_desk}/new"
    end

    def help_message_path_for_desk(ticket)
      "#{help_messages_path_for_desk}/#{ticket.id}"
    end

    def staff_ticket_update_path_for(ticket)
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      "#{path}/tickets/#{ticket.id}"
    end

    def support_ticket_status_label(ticket)
      {
        "open" => "Open",
        "waiting_on_customer" => "Waiting on customer",
        "waiting_on_support" => "Waiting on support",
        "resolved" => "Resolved"
      }.fetch(ticket.status.to_s, ticket.status.to_s.humanize)
    end

    def support_ticket_priority_label(priority)
      {
        "low" => "Low",
        "normal" => "Normal",
        "high" => "High"
      }.fetch(priority.to_s, priority.to_s.humanize)
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

    def support_ticket_status_label_for(status)
      {
        "open" => "Open",
        "waiting_on_customer" => "Waiting on customer",
        "waiting_on_support" => "Waiting on support",
        "resolved" => "Resolved"
      }.fetch(status.to_s, status.to_s.humanize)
    end

    def support_ticket_priority_options
      SupportTicket::PRIORITIES.map { |priority| [support_ticket_priority_label(priority), priority] }
    end

    def support_ticket_assignee_value(assignee)
      return "" if assignee.blank?

      "#{assignee.class.name}:#{assignee.id}"
    end

    def support_ticket_assignee_options(selected: nil)
      options = [["Unassigned", ""]]
      RecordingStudioSupport::Messages.staff_actors.each do |staff|
        options << [message_sender_name(staff), support_ticket_assignee_value(staff)]
      end
      if selected.present? && options.none? { |(_, value)| value == support_ticket_assignee_value(selected) }
        options << [message_sender_name(selected), support_ticket_assignee_value(selected)]
      end
      options
    end
  end
end
