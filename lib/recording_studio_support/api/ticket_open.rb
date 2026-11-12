# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class TicketOpen
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        cached = cached_idempotent_response
        return cached if cached

        TicketAccess.authorize_view!(context)
        result = { json: Serialize.recording(open_ticket!, context: context), status: :created }
        store_idempotent_response(result)
        result
      end

      private

      attr_reader :context

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

      def cached_idempotent_response
        key = context.idempotency_key
        return if key.blank? || !defined?(RecordingStudioApi::IdempotencyStore)

        payload = RecordingStudioApi::IdempotencyStore.fetch(
          api: context.api_key,
          client_id: context.api_client.id,
          key: key
        )
        return if payload.blank?

        { json: payload.fetch("json"), status: payload.fetch("status", "created").to_sym }
      end

      def store_idempotent_response(result)
        key = context.idempotency_key
        return if key.blank? || !defined?(RecordingStudioApi::IdempotencyStore)

        RecordingStudioApi::IdempotencyStore.write(
          api: context.api_key,
          client_id: context.api_client.id,
          key: key,
          payload: result.fetch(:json),
          status: result.fetch(:status, :created).to_s
        )
      end
    end
  end
end
