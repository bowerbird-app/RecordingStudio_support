# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class ShowCenter < Show
      private

      def target_recording
        Lookup.center!(id: Payload.member_id(context))
      end
    end
  end
end
