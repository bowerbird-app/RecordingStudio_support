# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketMessages
      class List
        def self.call(context)
          new(context).call
        end

        def initialize(context)
          @context = context
        end

        def call
          TicketMessages.authorize_read!(@context)
          group = TicketMessages.conversation!(@context)
          rows = RecordingStudioMessages.message_recordings(group)
          { records: rows.map { |row| TicketMessages.serialize_message(row) } }
        end
      end
    end
  end
end
