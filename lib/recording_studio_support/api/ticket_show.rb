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
        { json: Serialize.recording(TicketAccess.find_recording!(context), context: context) }
      end

      private

      attr_reader :context

      def authorize!
        if Access.operations_api?(context)
          TicketAccess.authorize_support_team!(context)
        else
          TicketAccess.authorize_view!(context)
        end
      end
    end
  end
end
