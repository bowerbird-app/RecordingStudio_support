# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class CreateCenter < Create
      private

      def create_recording!
        actor = Access.write_actor(context)
        parent_id = Payload.parent_id(context)
        raise_missing_parent! if parent_id.blank?

        SupportCenters.create!(parent_recording: Lookup.parent_root!(id: parent_id), actor: actor)
      rescue RecordingStudio::InvalidParent => e
        raise_invalid_parent_input!(e.message)
      end
    end
  end
end
