# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketUpdate
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        TicketAccess.authorize_support_team!(context)
        { json: Serialize.recording(update_ticket!, context: context) }
      end

      private

      attr_reader :context

      def update_ticket!
        attrs = Payload.attributes(context)
        ticket = Tickets.find!(Payload.member_id(context))
        Tickets.update!(ticket, actor: TicketAccess.actor(context), **ticket_changes(attrs))
        Tickets.recording_for!(Tickets.find!(ticket.id))
      rescue ActiveRecord::RecordNotFound
        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope"
      rescue ArgumentError, ActiveRecord::RecordInvalid => e
        TicketAccess.invalid_input!(e)
      end

      def ticket_changes(attrs)
        changes = {}
        changes[:status] = attrs[:status] if attrs.key?(:status)
        changes[:priority] = attrs[:priority] if attrs.key?(:priority)
        changes
      end
    end
  end
end
