# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module Widgets
      SECTIONS = RecordingStudioAdmin::Widget.new("widgets.support.sections") do
        type :list
        title "Sections"
        info "Pages live in a section. Open one or add another."
        list_options({ divider: true, hover: true, compact_preview: :text_summary })
        items do |_context|
          Queries.kept_section_recordings.map do |recording|
            {
              icon: :folder,
              text: recording.recordable&.title.presence || "Untitled section",
              href: Queries.section_path(recording)
            }
          end
        end
        link_to { |_context| Queries.new_section_path }
        link_label "New section"
      end

      RECENT_PAGES = RecordingStudioAdmin::Widget.new("widgets.support.recent_pages") do
        type :list
        title "Latest pages"
        info "Newest help pages first. Open the list to edit one."
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
