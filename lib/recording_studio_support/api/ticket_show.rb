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
        TicketAccess.authorize_read!(context)
      end

      def shown_recording
        TicketAccess.find_recording!(context)
      end
    end
  end
end
