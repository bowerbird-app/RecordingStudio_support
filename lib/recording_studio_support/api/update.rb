# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Update
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        reject_parent_id_input!
        Access.authorize_edit!(context)

        recording = context.recording
        attrs = Payload.attributes(context)
        recordable = recording.recordable
        actor = Access.actor_for(context)

        revised = if context.recordable_type == Api::SECTION_TYPE
                    Sections.revise!(
                      recording: recording,
                      title: attrs.fetch(:title, recordable.title),
                      icon: attrs.fetch(:icon, recordable.icon),
                      actor: actor
                    )
                  else
                    Pages.revise!(
                      recording: recording,
                      title: attrs.fetch(:title, recordable.title),
                      body: attrs.key?(:body) ? attrs[:body] : recordable.body,
                      description: attrs.fetch(:description, recordable.description),
                      icon: attrs.fetch(:icon, recordable.icon),
                      actor: actor
                    )
                  end

        { json: Serialize.recording(revised, context: context) }
      end

      private

      attr_reader :context

      def reject_parent_id_input!
        return if context.parent_recording
        return unless Payload.request_hash(context).key?(:parent_id)

        raise RecordingStudioApi::InvalidActionInputError,
              "parent_id is not permitted for updates; use the move action instead"
      end
    end
  end
end
