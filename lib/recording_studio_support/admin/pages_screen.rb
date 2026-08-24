# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class PagesScreen < RecordingStudioAdmin::Screen
      key "support_pages"
      icon :document_text
      title "Support pages"
      subtitle "Every help page, draft or live."

      button :new_page,
             text: "New page",
             url: ->(_context) { Queries.new_page_path },
             style: :primary

      SEARCH_FILTER = lambda { |relation, value, _context|
        Queries.search_page_recordings(relation, value)
      }
      STATUS_FILTER = lambda { |relation, value, _context|
        Queries.filter_page_recordings_by_status(relation, value)
      }
      SECTION_FILTER = lambda { |relation, value, _context|
        Queries.filter_page_recordings_by_section(relation, value)
      }
      SECTION_OPTIONS = -> { Queries.section_filter_options }
      TITLE_VALUE = ->(row, _context) { row.recordable&.title }
      SECTION_VALUE = ->(row, _context) { Queries.page_section_title(row) }
      STATUS_VALUE = ->(row, _context) { Queries.page_status(row) }
      STATUS_BADGE = lambda { |_row, _context, value|
        { text: value, style: Queries.page_status_badge_style(value), size: :sm }
      }
      EDIT_URL = ->(row, _context) { Queries.edit_page_path(row) }
      MOVE_URL = ->(row, _context) { Queries.move_page_path(row) }

      query do |_context|
        Queries.kept_page_recordings.includes(:recordable, parent_recording: :recordable)
               .order(updated_at: :desc)
      end

      table do
        title "\u00A0"
        hide_count
        filter :search, apply: SEARCH_FILTER
        filter :status, options: %w[Published Draft], apply: STATUS_FILTER
        filter :section, options: SECTION_OPTIONS, apply: SECTION_FILTER
        column :title, title: "Title", sortable: false, value: TITLE_VALUE
        column :section, title: "Section", sortable: false, value: SECTION_VALUE
        column :status, title: "Status", sortable: false, display: :badge,
                        display_options: STATUS_BADGE, value: STATUS_VALUE
        column :updated_at, title: "Updated"
        action :edit, text: "Edit", icon: "pencil-square", url: EDIT_URL
        action :move, text: "Move", icon: "arrow-right-circle", url: MOVE_URL
        paginate per_page: 25
        default_sort :updated_at, direction: :desc
      end
    end
  end
end
