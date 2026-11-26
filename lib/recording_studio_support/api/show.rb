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
        return public_page! if public_page?

        Lookup.routed!(context)
      end

      def public_page?
        !Access.operations_api?(context) && context.recordable_type == Api::PAGE_TYPE
      end

      def public_page!
        center = SupportCenters.current
        Lookup.raise_not_found("Resource was not found in this API scope") unless center

        recording = Pages.kept_pages_for_center(center).includes(:recordable).find_by(id: Payload.member_id(context))
        Lookup.raise_not_found("Resource was not found in this API scope") unless recording

        recording
      end

      def hide_draft!(recording)
        return if Access.can_view_as_support_team?(context)
        return unless recording.recordable_type == Api::PAGE_TYPE
        return if Pages.customer_visible_recording?(recording, actor: Access.actor_for(context))

        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope"
      end
    end
  end
end
