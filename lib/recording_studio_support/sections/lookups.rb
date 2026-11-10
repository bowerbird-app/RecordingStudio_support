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

      def find!(id:)
        RecordingStudio::Recording.where(
          recordable_type: SUPPORT_SECTION_TYPE
        ).includes(:recordable).find(id)
      end

      def find_kept_by_slug!(slug:)
        recording = RecordingStudioSupport::Sections.kept
                                                    .joins(RecordingStudioSupport::Sections.section_join_sql)
                                                    .where(recording_studio_support_sections: { slug: slug.to_s })
                                                    .includes(:recordable)
                                                    .first
        raise ActiveRecord::RecordNotFound if recording.blank?

        recording
      end

      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      def public_key_uuid?(key)
        key.to_s.match?(UUID_PATTERN)
      end

      def allowed_parent_root?(root_recording)
        return false unless root_recording

        root_recording.recordable_type == SupportCenters::TYPE ||
          parent_types.include?(root_recording.recordable_type)
      end

      def default_parent_root
        parent = RecordingStudio::Recording.find_by(
          recordable_type: RecordingStudioSupport.parent_root_type,
          parent_recording_id: nil,
          trashed_at: nil
        )
        SupportCenters.for_parent(parent) || parent
      end

      def parent_root_for(root_recording)
        Sections.parent_center_for(root_recording) || default_parent_root
      end

      def parent_types
        [SupportCenters::TYPE, RecordingStudioSupport.parent_root_type].uniq
      end
    end
  end
end
