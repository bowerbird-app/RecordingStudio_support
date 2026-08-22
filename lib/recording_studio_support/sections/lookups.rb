# frozen_string_literal: true

module RecordingStudioSupport
  module Sections
    module Lookups
      def find_kept!(id:)
        RecordingStudio::Recording.where(
          recordable_type: SUPPORT_SECTION_TYPE,
          trashed_at: nil
        ).includes(:recordable).find(id)
      end

      def allowed_parent_root?(root_recording)
        return false unless root_recording

        parent_types.include?(root_recording.recordable_type)
      end

      def default_parent_root
        RecordingStudio::Recording.where(
          recordable_type: parent_types,
          parent_recording_id: nil,
          trashed_at: nil
        ).order(:created_at).first
      end

      def parent_root_for(root_recording)
        return root_recording if allowed_parent_root?(root_recording)

        default_parent_root
      end

      def parent_types
        RecordingStudio.declared_allowed_parent_types_for(SUPPORT_SECTION_TYPE)
      end
    end
  end
end
