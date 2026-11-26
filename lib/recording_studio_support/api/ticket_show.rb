# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketShow
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        authorize!
        { json: Serialize.recording(shown_recording, context: context) }
      end

      private

      attr_reader :context

      def authorize!
        if Access.operations_api?(context)
          Access.authorize_support_team_view!(context)
        else
          TicketAccess.authorize_view!(context)
        end
      end

      def shown_recording
        return TicketAccess.find_recording!(context) unless Access.operations_api?(context)

        Lookup.routed!(context)
      end
    end
  end
end
