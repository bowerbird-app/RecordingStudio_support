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
        Tickets.update!(
          TicketAccess.find_recording!(context),
          actor: TicketAccess.actor(context),
          **ticket_changes(attrs)
        )
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
