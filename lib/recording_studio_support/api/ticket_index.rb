# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketIndex < Index
      private

      def authorize_index!
        TicketAccess.authorize_read!(context)
      end

      def filtered_recordings
        TicketAccess.recordings_for(context)
      end
    end
  end
end
