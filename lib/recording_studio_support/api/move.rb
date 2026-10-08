# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Move
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_edit!(context)
        recording = Pages.move!(
          recording: context.recording,
          parent_recording: destination_section!,
          actor: Access.actor_for(context)
        )
        { json: Serialize.recording(recording, context: context) }
      end

      private

      attr_reader :context

      def destination_section!
        parent_id = value_for(:parent_id)
        raise RecordingStudioApi::InvalidActionInputError, "parent_id is required for move" if parent_id.blank?

        Sections.find_kept!(id: parent_id)
      rescue ActiveRecord::RecordNotFound
        raise RecordingStudioApi::NotFoundError, "Destination recording was not found"
      end

      def value_for(key)
        params = context.params
        return unless params.respond_to?(:[])

        params[key].presence || params[key.to_s].presence
      end
    end
  end
end
