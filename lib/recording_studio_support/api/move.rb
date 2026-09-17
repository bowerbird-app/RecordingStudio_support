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
        destination = find_destination!

        Pages.move!(
          recording: context.recording,
          parent_recording: destination,
          actor: Access.actor_for(context)
        )
      end

      private

      attr_reader :context

      def find_destination!
        destination_id = %i[parent_id destination_id new_parent_id].filter_map do |key|
          value_for(key)
        end.first
        raise RecordingStudioApi::InvalidActionInputError, "parent_id is required for move" if destination_id.blank?

        destination = RecordingStudio::Recording.find_by(id: destination_id, trashed_at: nil)
        raise RecordingStudioApi::NotFoundError, "Destination recording was not found" if destination.nil?

        destination
      end

      def value_for(key)
        params = context.params
        return unless params.respond_to?(:[])

        params[key].presence || params[key.to_s].presence
      end
    end
  end
end
