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
        { json: Serialize.recording(revise_recording!, context: context) }
      end

      private

      attr_reader :context

      def revise_recording!
        actor = Access.actor_for(context)
        attrs = Payload.attributes(context)
        recordable = context.recording.recordable
        return revise_section!(attrs, recordable, actor) if context.recordable_type == Api::SECTION_TYPE

        revise_page!(attrs, recordable, actor)
      end

      def revise_section!(attrs, recordable, actor)
        Sections.revise!(
          recording: context.recording,
          title: attrs.fetch(:title, recordable.title),
          icon: attrs.fetch(:icon, recordable.icon),
          actor: actor
        )
      end

      def revise_page!(attrs, recordable, actor)
        Pages.revise!(
          recording: context.recording,
          title: attrs.fetch(:title, recordable.title),
          body: attrs.key?(:body) ? attrs[:body] : recordable.body,
          description: attrs.fetch(:description, recordable.description),
          icon: attrs.fetch(:icon, recordable.icon),
          actor: actor
        )
      end

      def reject_parent_id_input!
        return if context.parent_recording
        return unless Payload.request_hash(context).key?(:parent_id)

        raise RecordingStudioApi::InvalidActionInputError,
              "parent_id is not permitted for updates; use the move action instead"
      end
    end
  end
end
