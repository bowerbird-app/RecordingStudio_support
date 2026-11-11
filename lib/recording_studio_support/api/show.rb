# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Show
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = target_recording
        if Access.operations_api?(context)
          Access.authorize_support_team_view!(context)
        else
          Access.authorize_view!(context, recording)
        end
        hide_draft!(recording)

        { json: Serialize.recording(recording, context: context) }
      end

      private

      attr_reader :context

      def target_recording
        case context.recordable_type
        when Api::CENTER_TYPE then Lookup.center!(id: Payload.member_id(context))
        when Api::SECTION_TYPE then Lookup.section!(id: Payload.member_id(context))
        else page_recording
        end
      end

      def page_recording
        return Lookup.page!(id: Payload.member_id(context)) unless Payload.nested?(context)

        Lookup.page_in_section!(
          section: Lookup.section!(id: context.parent_id),
          id: context.relationship_id
        )
      end

      def hide_draft!(recording)
        return if Access.can_view_as_support_team?(context)
        return unless recording.recordable_type == Api::PAGE_TYPE
        return if recording.recordable.indexable?

        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope"
      end
    end
  end
end
