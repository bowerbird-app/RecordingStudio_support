# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class SectionsScreen < RecordingStudioAdmin::Screen
      key "support_sections"
      icon :folder
      title "Support sections"
      subtitle "Every help section."

      button :new_section,
             text: "New section",
             url: ->(_context) { Queries.new_section_path },
             style: :primary

      SEARCH_FILTER = lambda { |relation, value, _context|
        Queries.search_section_recordings(relation, value)
      }
      TITLE_VALUE = ->(row, _context) { row.recordable&.title }
      PAGE_COUNT_VALUE = ->(row, _context) { Queries.section_page_count(row) }
      EDIT_URL = ->(row, _context) { Queries.edit_section_path(row) }

      query do |_context|
        Queries.kept_section_recordings.order(updated_at: :desc)
      end

      table do
        title "\u00A0"
        hide_count
        filter :search, apply: SEARCH_FILTER
        column :title, title: "Name", sortable: false, value: TITLE_VALUE
        column :page_count, title: "Count", sortable: false, value: PAGE_COUNT_VALUE
        column :updated_at, title: "Updated"
        action :edit, text: "Edit", icon: "pencil-square", url: EDIT_URL
        paginate per_page: 25
        default_sort :updated_at, direction: :desc
      end
    end
  end
end
