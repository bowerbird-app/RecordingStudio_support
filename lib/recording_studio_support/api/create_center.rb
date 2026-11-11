# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class CreateCenter < Create
      private

      def create_recording!
        create_center!
      end

      def create_center!
        actor = Access.write_actor(context)
        parent_id = Payload.parent_id(context)
        raise_missing_parent! if parent_id.blank?

        SupportCenters.create!(parent_recording: Lookup.parent_root!(id: parent_id), actor: actor)
      rescue RecordingStudio::InvalidParent => e
        details = [{ attribute: :parent_id, message: "is not allowed for #{context.recordable_type}",
                     full_message: e.message, type: :invalid }]
        raise RecordingStudioApi::InvalidActionInputError.new(e.message, details: details)
      end
    end
  end
end
