# frozen_string_literal: true

module RecordingStudioSupport
  module McpCopy
    module TicketOperationCopy
      module_function

      def note_for(verb)
        case verb.to_sym
        when :create then create_note
        when :update then update_note
        end
      end

      def close_title
        "Close support ticket"
      end

      def close_description
        [close_lead, TypeDescriptions::BY_TYPE.fetch(Api::TICKET_TYPE)].join(" ")
      end

      def create_note
        "Pass subject and body at the root, not nested under attributes. body is the first message. " \
          "priority is optional (#{SupportTicket::PRIORITIES.join(', ')}). " \
          "Support files the ticket under the support centre. " \
          "This also creates the conversation and posts that first message. " \
          "Later replies use reply_to_support_ticket."
      end

      def update_note
        "Pass the ticket recording id. Send status (open or resolved) and/or priority " \
          "(#{SupportTicket::PRIORITIES.join(', ')}) at the root, not nested under attributes. " \
          "Replies use reply_to_support_ticket."
      end

      def close_lead
        "Resolves a support ticket. Pass the ticket recording id. " \
          "A ticket that is already resolved stays resolved. " \
          "A later reply from the requester reopens it."
      end
    end
  end
end
