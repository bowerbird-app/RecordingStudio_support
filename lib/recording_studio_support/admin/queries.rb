# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module Queries
      module_function

      def kept_page_recordings
        RecordingStudio::Recording.where(
          recordable_type: Pages::SUPPORT_PAGE_TYPE,
          trashed_at: nil
        )
      end

      def recent_page_recordings(limit: 8)
        kept_page_recordings.includes(:recordable).order(created_at: :desc).limit(limit)
      end

      def page_count
        kept_page_recordings.count
      end

      def page_view_count
        return 0 unless defined?(PageView) && PageView.table_exists?

        PageView.count
      end

      def page_path(recording)
        prefix = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
        "#{prefix}/#{recording.id}"
      end
    end
  end
end
