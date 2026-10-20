# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class TimeToCloseScreen < RecordingStudioAdmin::Screen
      key "time_to_close"
      icon :clock
      title "Time to close"
      subtitle "Resolved tickets, newest close first."
      blast_radius :site

      SUBJECT_VALUE = ->(row, _context) { row.subject }
      CLOSED_IN_VALUE = ->(row, _context) { closed_in_label(row) }
      DESK_URL = ->(row, _context) { OpenTicketsScreen.desk_path(row) }

      query do |_context|
        tickets
      end

      summary do
        hide_metric
        hide_change
        hide_period
      end

      chart do
        title "Mean time to close"
        type :line
        series { |context| DurationAxis.series("support_tickets.avg_time_to_resolve", context) }
        options do
          {
            yaxis: { min: 0, forceNiceScale: true, decimalsInFloat: 1 }
          }
        end
      end

      table do
        title "\u00A0"
        hide_count
        column :subject, title: "Subject", sortable: false, value: SUBJECT_VALUE
        column :closed_in, title: "Closed in", sortable: false, value: CLOSED_IN_VALUE
        column :resolved_at, title: "Closed"
        action :desk, text: "Desk", icon: "chat-bubble-left-right", url: DESK_URL
        paginate per_page: 25
        default_sort :resolved_at, direction: :desc
      end

      def self.path
        "/admin/screens/time_to_close"
      end

      def self.tickets
        RecordingStudioSupport::SupportTicket.where(status: "resolved").where.not(resolved_at: nil)
                                             .order(resolved_at: :desc)
      end

      def self.closed_in_label(ticket)
        created_at = ticket.created_at
        resolved_at = ticket.resolved_at
        return Widgets.age_label(nil) if created_at.blank? || resolved_at.blank?

        Widgets.age_label(resolved_at - created_at)
      end
    end
  end
end
