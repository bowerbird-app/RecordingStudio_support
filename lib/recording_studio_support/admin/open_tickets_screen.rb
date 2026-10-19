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

      query do |_context|
        tickets
      end

      table do
        title "\u00A0"
        hide_count
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

      def self.tickets
        RecordingStudioSupport::SupportTicket.where(status: "open").order(created_at: :asc)
      end

      def self.wait_label(ticket)
        created_at = ticket.created_at
        return Widgets.age_label(nil) if created_at.blank?

        Widgets.age_label(Time.current - created_at)
      end

      def self.desk_path(ticket)
        group_id = ticket.message_group_id
        return Queries.staff_messages_path if group_id.blank?

        "#{Queries.staff_messages_path}?group_id=#{group_id}"
      end
    end
  end
end
