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

      def kept_section_recordings
        Sections.kept.includes(:recordable).order(:created_at)
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

      def move_page_path(recording)
        "#{moveable_prefix}/move/#{recording.id}"
      end

      def section_path(recording)
        "#{pages_prefix}/sections/#{recording.id}"
      end

      def new_section_path
        "#{pages_prefix}/sections/new"
      end

      def edit_section_path(recording)
        "#{section_path(recording)}/edit"
      end

      def search_section_recordings(relation, value)
        Sections.apply_query(relation, value)
      end

      def admin_pages_screen_path
        "/admin/screens/support_pages"
      end

      def admin_sections_screen_path
        "/admin/screens/support_sections"
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

      def page_section_title(recording)
        Pages.section_for(recording)&.recordable&.title
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

      def filter_page_recordings_by_section(relation, value)
        title = value.to_s.strip
        return relation if title.blank?

        section_ids = kept_section_recordings.filter_map do |recording|
          recording.id if recording.recordable&.title == title
        end
        relation.where(parent_recording_id: section_ids)
      end

      def section_filter_options
        kept_section_recordings.filter_map { |recording| recording.recordable&.title }.uniq.sort
      end

      def pages_prefix
        RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      end

      def moveable_prefix
        "/recording_studio_moveable"
      end
    end
  end
end
