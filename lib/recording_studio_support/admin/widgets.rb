# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module Widgets
      PAGE_COUNT = RecordingStudioAdmin::Widget.new("widgets.support.page_count") do
        type :number
        title "Help pages"
        info "How many help pages are live right now."
        hide_change
        hide_period
        value { |_context| Queries.page_count }
        link_to { |context| context.admin_screen_path("help_pages") }
      end

      PAGE_VIEWS = RecordingStudioAdmin::Widget.new("widgets.support.page_views") do
        type :number
        title "Reads"
        info "Times someone opened a help page. These are notes, not extra pages."
        hide_change
        hide_period
        value { |_context| Queries.page_view_count }
      end

      RECENT_PAGES = RecordingStudioAdmin::Widget.new("widgets.support.recent_pages") do
        type :list
        title "Latest pages"
        info "Newest help pages first. Open one to read it."
        list_options({ divider: true, hover: true, compact_preview: :text_summary })
        items do |_context|
          Queries.recent_page_recordings.map do |recording|
            {
              icon: :document_text,
              text: recording.recordable&.title.presence || "Untitled page",
              href: Queries.page_path(recording)
            }
          end
        end
        link_to { |context| context.admin_screen_path("help_pages") }
        link_label "See every page"
      end
    end
  end
end
