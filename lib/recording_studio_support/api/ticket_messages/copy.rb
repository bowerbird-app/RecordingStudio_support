# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketMessages
      module Copy
        LIST_TITLE = "List support ticket messages"
        REPLY_TITLE = "Reply to support ticket"
        MARK_READ_TITLE = "Mark support ticket read"
        UNREAD_TITLE = "Count unread support tickets"

        LIST =
          "A support ticket is a signed-in help request. This lists the messages on that " \
          "ticket's conversation, oldest first. Pass the ticket recording id from " \
          "list_support_tickets, show_support_ticket, or open_support_ticket. " \
          "The ticket must already exist."
        REPLY =
          "Post a message on a support ticket's conversation. Pass the ticket recording id " \
          "and body. The ticket must already exist. Opening a ticket with open_support_ticket " \
          "already posts the first message; use this for later replies. A requester reply on " \
          "a resolved ticket reopens it."
        MARK_READ =
          "Mark a support ticket's conversation read for the signed-in person. Pass the " \
          "ticket recording id. The ticket must already exist."
        UNREAD =
          "Count unread support tickets for the signed-in person. Uses the same ticket " \
          "conversations as list_support_tickets. Returns unread_count."

        BY_NAME = {
          list_support_ticket_messages: { title: LIST_TITLE, description: LIST },
          reply_to_support_ticket: { title: REPLY_TITLE, description: REPLY },
          mark_support_ticket_read: { title: MARK_READ_TITLE, description: MARK_READ },
          count_unread_support_tickets: { title: UNREAD_TITLE, description: UNREAD }
        }.freeze

        module_function

        def copy_for(name)
          BY_NAME.fetch(name.to_sym)
        end
      end
    end
  end
end
