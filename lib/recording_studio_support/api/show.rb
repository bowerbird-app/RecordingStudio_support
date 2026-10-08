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
        recording = context.recording
        if Access.operations_api?(context)
          Access.authorize_staff_view!(context)
        else
          Access.authorize_view!(context, recording)
        end
        hide_draft!(recording)

        { json: Serialize.recording(recording, context: context) }
      end

      private

      attr_reader :context

      def hide_draft!(recording)
        return if Access.can_view_as_staff?(context)
        return unless recording.recordable_type == Api::PAGE_TYPE
        return if recording.recordable.indexable?

        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope"
      end
    end
  end
end
