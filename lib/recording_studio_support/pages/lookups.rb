# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module Lookups
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
    end
  end
end
