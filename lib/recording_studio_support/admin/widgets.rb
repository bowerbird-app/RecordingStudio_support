# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module Widgets
      METRIC_PARAMS = { site_authorized: true, scope: :site }.freeze

      module_function

      def metric_value(identifier, admin_context)
        RecordingStudioMetrics::Admin.scalar_value(
          identifier,
          admin_context: admin_context,
          **METRIC_PARAMS
        )
      end

      def metric_series(identifier, admin_context)
        RecordingStudioMetrics::Admin.chart_series(
          identifier,
          admin_context: admin_context,
          **METRIC_PARAMS
        )
      end

      def age_label(seconds)
        return "None" if seconds.nil?

        total = seconds.to_i
        return "0s" if total <= 0

        days, remainder = total.divmod(86_400)
        hours, remainder = remainder.divmod(3_600)
        minutes, secs = remainder.divmod(60)
        format_age_parts(days, hours, minutes, secs)
      end

      def format_age_parts(days, hours, minutes, secs)
        parts = []
        parts << "#{days}d" if days.positive?
        parts << "#{hours}h" if hours.positive?
        parts << "#{minutes}m" if minutes.positive? && days.zero?
        parts << "#{secs}s" if parts.empty?
        parts.join(" ")
      end

      PAGE_COUNT = RecordingStudioAdmin::Widget.new("widgets.support.page_count") do
        type :number
        title "Support pages"
        value { Queries.kept_page_recordings.count }
        hide_change
        hide_period
      end

      UNASSIGNED_OPEN = RecordingStudioAdmin::Widget.new("widgets.support.unassigned_open") do
        type :number
        title "Unassigned tickets"
        info "Open tickets with nobody on them yet."
        hide_change
        hide_period
        blast_radius :site
        value { |context| Widgets.metric_value("support_tickets.unassigned_open", context) }
        link_to { Queries.staff_messages_path }
        link_label "Desk"
      end

      OLDEST_OPEN_AGE = RecordingStudioAdmin::Widget.new("widgets.support.oldest_open_age") do
        type :number
        title "Oldest open ticket"
        info "How long the oldest open ticket has been waiting. None when the queue is empty."
        hide_change
        hide_period
        blast_radius :site
        value { |context| Widgets.age_label(Widgets.metric_value("support_tickets.oldest_open_age", context)) }
        link_to { OpenTicketsScreen.path }
        link_label "Open tickets"
      end

      AVG_TIME_TO_RESOLVE = RecordingStudioAdmin::Widget.new("widgets.support.avg_time_to_resolve") do
        type :chart
        chart_type :line
        title "Time to close"
        info "Mean time from open to resolved, by the day they closed. Minutes, hours, or days."
        hide_change
        hide_period
        blast_radius :site
        series { |context| DurationAxis.series("support_tickets.avg_time_to_resolve", context) }
        chart_options do
          {
            yaxis: { min: 0, forceNiceScale: true, decimalsInFloat: 1 }
          }
        end
        link_to { Queries.staff_messages_path }
        link_label "Desk"
      end

      PAGE_VIEWS = RecordingStudioAdmin::Widget.new("widgets.support.page_views") do
        type :chart
        chart_type :line
        title "Help page views"
        info "Each page open counts once. Not unique people."
        hide_change
        hide_period
        blast_radius :site
        series { |context| Widgets.metric_series("support_page_views.over_time", context) }
        link_to { Queries.admin_pages_screen_path }
        link_label "Support pages"
      end

      ALL = [
        PAGE_COUNT,
        UNASSIGNED_OPEN,
        OLDEST_OPEN_AGE,
        AVG_TIME_TO_RESOLVE,
        PAGE_VIEWS
      ].freeze
    end
  end
end
