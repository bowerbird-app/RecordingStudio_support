# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class HelpPageViewsScreen < RecordingStudioAdmin::Screen
      key "help_page_views"
      icon :eye
      title "Help page views"
      subtitle "Each page open, newest first."
      blast_radius :site

      PAGE_VALUE = ->(row, _context) { page_title(row) }

      query do |_context|
        views
      end

      filter_presentation :inline
      filter :date_range, field: :created_at, default: :last_30_days
      filter :group_by, values: ChartFilters::GROUPS, default: :day

      summary do
        hide_metric
        hide_change
        hide_period
      end

      chart do
        title "Views over time"
        type :line
        series do |context|
          Widgets.metric_series("support_page_views.over_time", context, **ChartFilters.metric_params(context))
        end
      end

      table do
        title "\u00A0"
        hide_count
        column :page, title: "Page", sortable: false, value: PAGE_VALUE
        column :created_at, title: "Opened"
        paginate per_page: 25
        default_sort :created_at, direction: :desc
      end

      def self.path
        "/admin/screens/help_page_views"
      end

      def self.views
        RecordingStudioSupport::PageView.order(created_at: :desc)
      end

      def self.page_title(view)
        recording_id = view.recording_id
        return "Help page" if recording_id.blank?

        recording = RecordingStudio::Recording.find_by(id: recording_id)
        recording&.recordable&.title.presence || "Help page"
      end
    end
  end
end
