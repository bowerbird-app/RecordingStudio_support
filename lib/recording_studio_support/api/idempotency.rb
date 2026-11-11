# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Idempotency
      private

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
