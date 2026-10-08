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
        authorize!
        recording = context.recording
        serialized = Serialize.recording(recording, context: context)
        trash!(recording)
        { json: serialized.merge(deleted: true, deleted_via: "trashed") }
      end

      private

      attr_reader :context

      def authorize!
        Access.refuse_public_sections!(context)
        Access.authorize_edit!(context)
      end

      def trash!(recording)
        actor = Access.actor_for(context)
        if context.recordable_type == Api::SECTION_TYPE
          Sections.trash!(recording: recording, actor: actor)
        else
          Pages.trash!(recording: recording, actor: actor)
        end
      end
    end
  end
end
