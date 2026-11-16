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
          recording: Lookup.routed!(context),
          parent_recording: destination_section!,
          actor: Access.write_actor(context)
        )
        { json: Serialize.recording(recording, context: context) }
      end

      private

      attr_reader :context

      def destination_section!
        parent_id = destination_id
        raise RecordingStudioApi::InvalidActionInputError, "parent_id is required for move" if parent_id.blank?

        RecordingStudioApi::ScopedRecording.find!(
          access_grant: context.access_grant,
          id: parent_id,
          recordable_type: Api::SECTION_TYPE
        )
      end

      def destination_id
        %i[parent_id destination_id new_parent_id].each do |key|
          value = value_for(key)
          return value if value.present?
        end

        nil
      end

      def value_for(key)
        params = context.params
        if params.respond_to?(:[])
          value = params[key].presence || params[key.to_s].presence
          return value if value.present?
        end

        raw = Payload.request_hash(context)
        raw[key].presence || raw[key.to_s].presence
      end
    end
  end
end
