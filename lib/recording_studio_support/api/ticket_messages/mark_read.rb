# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketMessages
      class MarkRead
        def self.call(context)
          new(context).call
        end

        def initialize(context)
          @context = context
        end

        def call
          TicketMessages.authorize!(@context)
          recording = TicketMessages.ticket_recording!(@context)
          group = TicketMessages.conversation!(@context)
          TicketMessages.wrap_messages_error do
            RecordingStudioMessages.mark_read(
              group_recording: group,
              actor: TicketAccess.actor(@context)
            )
          end
          Serialize.recording(recording, context: @context)
        end
      end
    end
  end
end
