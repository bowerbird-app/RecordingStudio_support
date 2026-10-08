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
        recording = target_recording
        serialized = Serialize.recording(recording, context: context)
        trash!(recording)
        { json: serialized.merge(deleted: true, deleted_via: "trashed") }
      end

      private

      attr_reader :context

      def target_recording
        return Lookup.section!(id: Payload.member_id(context), include_trashed: true) if section?

        Lookup.page!(id: page_id, include_trashed: true).then do |page|
          next page unless Payload.nested?(context)
          next page if page.parent_recording_id.to_s == context.parent_id.to_s

          Lookup.raise_not_found("Relationship resource was not found")
        end
      end

      def section?
        context.recordable_type == Api::SECTION_TYPE
      end

      def page_id
        Payload.nested?(context) ? context.relationship_id : Payload.member_id(context)
      end

      def trash!(recording)
        actor = Access.write_actor(context)
        if context.recordable_type == Api::SECTION_TYPE
          Sections.trash!(recording: recording, actor: actor)
        else
          Pages.trash!(recording: recording, actor: actor)
        end
      end
    end
  end
end
