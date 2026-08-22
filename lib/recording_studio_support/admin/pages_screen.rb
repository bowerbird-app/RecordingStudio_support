# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class PagesScreen < RecordingStudioAdmin::Screen
      key "help_pages"
      icon :document_text
      title "Help pages"
      subtitle "Every help page, draft or live."

      button :new_page,
             text: "New",
             url: ->(_context) { Queries.new_page_path },
             style: :primary

      SEARCH_FILTER = lambda { |relation, value, _context|
        Queries.search_page_recordings(relation, value)
      }
      STATUS_FILTER = lambda { |relation, value, _context|
        Queries.filter_page_recordings_by_status(relation, value)
      }
      TITLE_VALUE = ->(row, _context) { row.recordable&.title }
      STATUS_VALUE = ->(row, _context) { Queries.page_status(row) }
      STATUS_BADGE = lambda { |_row, _context, value|
        { text: value, style: Queries.page_status_badge_style(value), size: :sm }
      }
      EDIT_URL = ->(row, _context) { Queries.edit_page_path(row) }

      query { |_context| Queries.kept_page_recordings.includes(:recordable).order(updated_at: :desc) }

      table do
        title "\u00A0"
        hide_count
        filter :search, apply: SEARCH_FILTER
        filter :status, options: %w[Published Draft], apply: STATUS_FILTER
        column :title, title: "Title", sortable: false, value: TITLE_VALUE
        column :status, title: "Status", sortable: false, display: :badge,
                        display_options: STATUS_BADGE, value: STATUS_VALUE
        column :updated_at, title: "Updated"
        action :edit, text: "Edit", icon: "pencil-square", url: EDIT_URL
        paginate per_page: 25
        default_sort :updated_at, direction: :desc
      end
    end
  end
end
