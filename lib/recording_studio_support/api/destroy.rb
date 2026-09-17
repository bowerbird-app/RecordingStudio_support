# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Destroy
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_edit!(context)

        recording = context.recording
        serialized = Serialize.recording(recording, context: context)
        actor = Access.actor_for(context)

        if context.recordable_type == Api::SECTION_TYPE
          Sections.trash!(recording: recording, actor: actor)
        else
          Pages.trash!(recording: recording, actor: actor)
        end

        { json: serialized.merge(deleted: true, deleted_via: "trashed") }
      end

      private

      attr_reader :context
    end
  end
end
