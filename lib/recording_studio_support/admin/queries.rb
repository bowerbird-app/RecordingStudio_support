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

      def page_path(recording)
        "#{pages_prefix}/#{recording.id}"
      end

      def edit_page_path(recording)
        "#{page_path(recording)}/edit"
      end

      def new_page_path
        "#{pages_prefix}/new"
      end

      def page_status(recording)
        if recording.respond_to?(:currently_published?) && recording.currently_published?
          "Published"
        else
          "Draft"
        end
      end

      def page_status_badge_style(status)
        status.to_s == "Published" ? :success : :info
      end

      def search_page_recordings(relation, value)
        Pages.apply_query(relation, value)
      end

      def filter_page_recordings_by_status(relation, value)
        published_ids = SupportPage.published.select(:id)

        case value.to_s
        when "Published"
          relation.where(recordable_id: published_ids)
        when "Draft"
          relation.where.not(recordable_id: published_ids)
        else
          relation
        end
      end

      def pages_prefix
        RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      end
    end
  end
end
