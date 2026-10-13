# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module Counts
      def kept_count_by_section(section_recordings)
        count_pages_by_section(section_recordings, published_only: false)
      end

      def public_count_by_section(section_recordings)
        count_pages_by_section(section_recordings, published_only: true)
      end

      def count_pages_by_section(section_recordings, published_only:)
        ids = Array(section_recordings).map(&:id)
        return {} if ids.empty?

        pages = kept_pages_for_sections(ids)
        pages = published_pages_in(pages) if published_only
        pages.group(:parent_recording_id).count
      end

      def kept_pages_for_sections(section_ids)
        RecordingStudio::Recording.where(
          parent_recording_id: section_ids,
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        )
      end

      def published_pages_in(pages)
        pages.where(recordable_id: SupportPage.indexable.where(id: pages.select(:recordable_id)).select(:id))
      end
    end
  end
end
