# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class OpenTicketsScreen < RecordingStudioAdmin::Screen
      key "open_tickets"
      icon :inbox
      title "Open tickets"
      subtitle "Oldest first. Same open queue as the age card."
      blast_radius :site

      SUBJECT_VALUE = ->(row, _context) { row.subject }
      WAIT_VALUE = ->(row, _context) { wait_label(row) }
      PRIORITY_VALUE = ->(row, _context) { row.priority.to_s.humanize }
      DESK_URL = ->(row, _context) { desk_path(row) }
      ASSIGNEE_FILTER = lambda { |relation, value, _context|
        case value.to_s
        when "Unassigned" then relation.where(assignee_id: nil)
        when "Assigned" then relation.where.not(assignee_id: nil)
        else relation
        end
      }

      query do |_context|
        tickets
      end

      table do
        title "\u00A0"
        hide_count
        filter :assignee, options: %w[Unassigned Assigned], apply: ASSIGNEE_FILTER
        column :subject, title: "Subject", sortable: false, value: SUBJECT_VALUE
        column :waiting, title: "Waiting", sortable: false, value: WAIT_VALUE
        column :priority, title: "Priority", sortable: false, value: PRIORITY_VALUE
        column :created_at, title: "Opened"
        action :desk, text: "Desk", icon: "chat-bubble-left-right", url: DESK_URL
        paginate per_page: 25
        default_sort :created_at, direction: :asc
      end

      def self.path
        "/admin/screens/open_tickets"
      end

      def self.unassigned_path
        "#{path}?assignee=Unassigned"
      end

      def self.tickets
        RecordingStudioSupport::Tickets.current.where(status: "open")
                                       .order("recording_studio_recordings.created_at ASC")
      end

      def self.wait_label(ticket)
        created_at = opened_at(ticket)
        return Widgets.age_label(nil) if created_at.blank?

        Widgets.age_label(Time.current - created_at)
      end

      def self.desk_path(ticket)
        group_id = desk_group_id(ticket)
        return Queries.staff_messages_path if group_id.blank?

        "#{Queries.staff_messages_path}?group_id=#{group_id}"
      end

      def self.opened_at(ticket)
        return ticket.created_at unless ticket.respond_to?(:id) && ticket.id.present?

        Tickets.recording_for_snapshot_id(ticket.id)&.created_at ||
          Tickets.ticket_recordings.find_by(recordable_id: ticket.id)&.created_at ||
          ticket.created_at
      end

      def self.desk_group_id(ticket)
        if ticket.respond_to?(:parent_recording_id) && ticket.parent_recording_id.present?
          return ticket.parent_recording_id
        end

        Tickets.group_recording_for(ticket)&.id
      end
    end
  end
end
