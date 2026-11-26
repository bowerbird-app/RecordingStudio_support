# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketClose
      NAME = :close_support_ticket
      PATH = "support_ticket_close/:id"
      TITLE = "Close support ticket"
      DESCRIPTION =
        "Resolve a ticket for the Accessible actor on the access grant. " \
        "Sets status to resolved and sets resolved_at when it is blank. " \
        "A ticket that is already resolved is unchanged. " \
        "A later requester reply reopens it."

      def self.register!
        return unless defined?(RecordingStudioApi)
        return if RecordingStudioApi.registered_endpoint(NAME, api: Registration::OPERATIONS_API)

        RecordingStudioApi.register_endpoint(
          NAME, api: Registration::OPERATIONS_API, http_verb: :post, path: PATH,
                handler: self, recordable_type: TICKET_TYPE, owns_scoping: true, openapi: openapi,
                input_contract: { reject_unknown: false, fields: {} }
        )
      end

      def self.openapi
        {
          tags: [PUBLIC_TICKET_TAG], tag: { group: "Support" }, title: TITLE, summary: TITLE,
          description: DESCRIPTION, parameters: [id_parameter]
        }
      end

      def self.id_parameter
        {
          name: "id", in: "path", required: true,
          schema: { type: "string" }, description: TicketMessages::TICKET_ID
        }
      end

      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        TicketAccess.authorize_support_team!(context)
        Serialize.recording(close_ticket!, context: context)
      end

      private

      attr_reader :context

      def close_ticket!
        Tickets.update!(
          TicketAccess.find_recording!(context),
          actor: TicketAccess.actor(context),
          status: :resolved
        )
      rescue ArgumentError, ActiveRecord::RecordInvalid => e
        TicketAccess.invalid_input!(e)
      end
    end
  end
end
