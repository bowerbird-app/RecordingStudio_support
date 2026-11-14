# frozen_string_literal: true

module RecordingStudioSupport
  module SupportCenters
    TYPE = "RecordingStudioSupport::SupportCenter"

    module_function

    def for_parent(parent_recording)
      return if parent_recording.blank?

      RecordingStudio::Recording.kept.find_by(
        parent_recording_id: parent_recording.id,
        recordable_type: TYPE
      )
    end

    def current
      for_parent(default_parent_root)
    end

    def kept
      RecordingStudio::Recording.kept.where(recordable_type: TYPE)
    end

    def create!(parent_recording:, actor: nil)
      AssignActor.assign_actor(actor) do
        parent_recording.record(SupportCenter, actor: actor)
      end
    end

    def current!
      current || raise(ArgumentError, "Create a SupportCenter under the configured parent root first.")
    end

    def default_parent_root
      RecordingStudio::Recording.kept.where(
        recordable_type: RecordingStudioSupport.parent_root_type,
        parent_recording_id: nil
      ).order(:created_at).first
    end

    def recording_for(center)
      return center if center.is_a?(RecordingStudio::Recording) && center.recordable_type == TYPE
      return if center.blank?

      RecordingStudio::Recording.kept.find_by(
        recordable: center,
        recordable_type: TYPE
      )
    end
  end
end
