# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class PagesScreen < RecordingStudioAdmin::Screen
      key "help_pages"
      icon :document_text
      title "Help pages"
      subtitle "Every help page still in play."
      query { |_context| Queries.kept_page_recordings.includes(:recordable).order(created_at: :desc) }

      table do
        column :page,
               title: "Page",
               sortable: false,
               value: ->(row, _context) { row.recordable&.title }
        column :created_at, title: "Added"
        action :open,
               text: "Open",
               icon: "arrow-top-right-on-square",
               url: ->(row, _context) { Queries.page_path(row) }
        paginate per_page: 25
        default_sort :created_at, direction: :desc
      end
    end
  end
end
