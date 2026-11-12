# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketOpen < Create
      def call
        cached = cached_idempotent_response
        return cached if cached

        TicketAccess.authorize_view!(context)
        result = { json: Serialize.recording(open_ticket!, context: context), status: :created }
        store_idempotent_response(result)
        result
      end

      private

      def open_ticket!
        attrs = Payload.attributes(context)
        Tickets.recording_for!(Tickets.open!(**open_attributes(attrs)))
      rescue ArgumentError, ActiveRecord::RecordInvalid, Tickets::AlreadyExists,
             RecordingStudioMessages::Error => e
        TicketAccess.invalid_input!(e)
      end

      def open_attributes(attrs)
        {
          actor: TicketAccess.actor(context),
          subject: attrs[:subject],
          body: attrs[:body],
          priority: attrs[:priority].presence || :normal
        }
      end
    end
  end
end
