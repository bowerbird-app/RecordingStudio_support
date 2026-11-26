# frozen_string_literal: true

require_relative "ticket_messages/copy"
require_relative "ticket_messages/list"
require_relative "ticket_messages/reply"
require_relative "ticket_messages/mark_read"
require_relative "ticket_messages/unread_count"
require_relative "ticket_messages/registration"

module RecordingStudioSupport
  module Api
    # Ticket-keyed wrappers around Messages services. These are Support
    # endpoints. They do not load the Messages :support preset. Paths stay
    # off the support_tickets resource prefix so the API does not treat them
    # as unknown ticket actions.
    module TicketMessages
      GROUP = "Support Messages"
      OPENAPI = { tags: [GROUP], tag: { group: GROUP } }.freeze
      LIST = :list_support_ticket_messages
      REPLY = :reply_to_support_ticket
      MARK_READ = :mark_support_ticket_read
      UNREAD_COUNT = :count_unread_support_tickets
      NAMES = [LIST, REPLY, MARK_READ, UNREAD_COUNT].freeze
      APIS = %i[public operations].freeze
      TICKET_ID = "Support ticket recording id from list_support_tickets, show_support_ticket, or open_support_ticket."
      BODY = "Message text posted on the ticket thread."

      module_function

      def register!
        Registration.register!
      end

      def authorize!(context)
        if Access.operations_api?(context)
          TicketAccess.authorize_support_team!(context)
        else
          TicketAccess.authorize_view!(context)
        end
      end

      def authorize_read!(context)
        TicketAccess.authorize_read!(context)
      end

      def ticket_recording!(context)
        return TicketAccess.find_recording!(context) unless Access.operations_api?(context)

        Lookup.routed!(context)
      end

      def conversation!(context)
        recording = ticket_recording!(context)
        group = Tickets.group_recording_for(recording.recordable)
        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if group.blank?

        authorize_conversation!(context, group)
        group
      end

      def authorize_conversation!(context, group)
        actor = TicketAccess.actor(context)
        Access.deny! if actor.blank?
        return if RecordingStudioAccessible.authorized?(actor: actor, recording: group, role: :view)

        Access.deny!
      end

      def serialize_message(recording)
        {
          id: recording.id,
          type: "Message",
          root_id: recording.root_recording_id,
          parent_id: recording.parent_recording_id,
          created_at: recording.created_at&.utc&.iso8601,
          body: recording.recordable&.body
        }
      end

      def wrap_messages_error
        yield
      rescue RecordingStudioMessages::NotAuthorized
        Access.deny!
      rescue RecordingStudioMessages::Error, ArgumentError => e
        TicketAccess.invalid_input!(e)
      end
    end
  end
end
