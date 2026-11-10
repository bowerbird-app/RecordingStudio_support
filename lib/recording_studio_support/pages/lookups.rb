# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module Lookups
      def for_root(root_recording, query: nil)
        center = Sections.parent_center_for(root_recording)
        return RecordingStudio::Recording.none unless center

        apply_query(kept_pages_for_center(center), query).preload(:recordable)
      end

      def for_section(section_recording, query: nil)
        return RecordingStudio::Recording.none unless section_recording

        scope = apply_query(kept_pages_for_section(section_recording), query)
        scope.reorder(:recording_studio_orderable_position, :created_at, :id).preload(:recordable)
      end

      def public_indexable(query: nil)
        apply_page_query(SupportPage.indexable, query).distinct.reorder(:title)
      end

      def public_for_section(section_recording, query: nil)
        return SupportPage.none unless section_recording

        page_ids = kept_pages_for_section(section_recording).pluck(:recordable_id)
        apply_page_query(SupportPage.indexable.where(id: page_ids), query).distinct.reorder(:title)
      end

      def related_public_for(page, section_recording: nil)
        section = section_recording || recording_for(page)&.then { |recording| section_for(recording) }
        return SupportPage.none if page.blank? || section.blank?

        public_for_section(section).where.not(id: page.id)
      end

      def find_for_root!(root_recording:, id:)
        center = Sections.parent_center_for(root_recording)
        kept_pages_for_center(center).includes(:recordable).find(id)
      end

      def find_kept!(id:)
        RecordingStudio::Recording.where(
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        ).includes(:recordable).find(id)
      end

      def find!(id:)
        RecordingStudio::Recording.where(
          recordable_type: SUPPORT_PAGE_TYPE
        ).includes(:recordable).find(id)
      end

      def default_section_for(root_recording)
        center = Sections.parent_center_for(root_recording) || SupportCenters.current
        return unless center

        Sections.for_root(center).first
      end

      def section_for(recording)
        parent = recording&.parent_recording
        return parent if parent&.recordable_type == Sections::SUPPORT_SECTION_TYPE

        nil
      end

      def recording_for(page)
        RecordingStudio::Recording.find_by(
          recordable: page,
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        )
      end

      def kept_pages(root_recording)
        RecordingStudio::Recording.where(
          root_recording_id: root_recording.id,
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        )
      end

      def kept_pages_for_center(center_recording)
        return RecordingStudio::Recording.none unless center_recording

        section_ids = Sections.kept_sections(center_recording).select(:id)
        RecordingStudio::Recording.where(
          parent_recording_id: section_ids,
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        )
      end

      def kept_pages_for_section(section_recording)
        return RecordingStudio::Recording.none unless section_recording

        RecordingStudio::Recording.where(
          parent_recording_id: section_recording.id,
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        )
      end

      def apply_query(relation, query)
        term = query.to_s.strip
        return relation if term.blank?

        matched_ids = SupportPage.search(term).unscope(:order).reselect(:id)
        relation.where(recordable_id: matched_ids)
      end

      def apply_page_query(relation, query)
        term = query.to_s.strip
        return relation if term.blank?

        relation.search(term)
      end
    end
  end
end
