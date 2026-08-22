# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module Lookups
      def for_root(root_recording, query: nil)
        workspace = Sections.parent_root_for(root_recording)
        return RecordingStudio::Recording.none unless workspace

        apply_query(kept_pages(workspace), query).preload(:recordable)
      end

      def for_section(section_recording, query: nil)
        return RecordingStudio::Recording.none unless section_recording

        scope = apply_query(kept_pages_for_section(section_recording), query)
        scope.reorder(:recording_studio_orderable_position, :created_at, :id).preload(:recordable)
      end

      def public_indexable(query: nil)
        apply_page_query(SupportPage.indexable, query).distinct.order(:title)
      end

      def public_for_section(section_recording, query: nil)
        return SupportPage.none unless section_recording

        page_ids = kept_pages_for_section(section_recording).pluck(:recordable_id)
        apply_page_query(SupportPage.indexable.where(id: page_ids), query).distinct.order(:title)
      end

      def find_for_root!(root_recording:, id:)
        workspace = Sections.parent_root_for(root_recording)
        kept_pages(workspace).includes(:recordable).find(id)
      end

      def find_kept!(id:)
        RecordingStudio::Recording.where(
          recordable_type: SUPPORT_PAGE_TYPE,
          trashed_at: nil
        ).includes(:recordable).find(id)
      end

      def default_section_for(root_recording)
        workspace = Sections.parent_root_for(root_recording)
        return unless workspace

        Sections.for_root(workspace).first
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

        pattern = page_query_pattern(term)
        relation.joins(support_page_join_sql).where(
          "recording_studio_support_pages.title ILIKE :q OR recording_studio_support_pages.body ILIKE :q",
          q: pattern
        )
      end

      def apply_page_query(relation, query)
        term = query.to_s.strip
        return relation if term.blank?

        table = SupportPage.table_name
        relation.where(
          "#{table}.title ILIKE :q OR #{table}.body ILIKE :q",
          q: page_query_pattern(term)
        )
      end

      def page_query_pattern(term)
        "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
      end

      def support_page_join_sql
        table = RecordingStudio::Recording.table_name
        type = ActiveRecord::Base.connection.quote(SUPPORT_PAGE_TYPE)
        "INNER JOIN recording_studio_support_pages " \
          "ON recording_studio_support_pages.id = #{table}.recordable_id " \
          "AND #{table}.recordable_type = #{type}"
      end
    end
  end
end
