# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketIndex < Index
      private

      def authorize_index!
        if Access.operations_api?(context)
          Access.authorize_support_team_view!(context)
        else
          TicketAccess.authorize_view!(context)
        end
      end

      def filtered_recordings
        TicketAccess.recordings_for(context)
      end
    end
  end
end
