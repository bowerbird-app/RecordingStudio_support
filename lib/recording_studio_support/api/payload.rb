# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Payload
      module_function

      def attributes(context)
        raw = request_hash(context)
        if raw.key?("attributes") || raw.key?(:attributes)
          raise RecordingStudioApi::InvalidActionInputError.new(
            "The attributes envelope is no longer supported; send writable fields at the request body root",
            details: [
              {
                attribute: :attributes,
                message: "is not supported",
                full_message: "Attributes is not supported",
                type: :unsupported
              }
            ]
          )
        end

        symbolized = raw.respond_to?(:deep_symbolize_keys) ? raw.deep_symbolize_keys : {}
        allowed = writable_keys(context)
        symbolized.slice(*allowed)
      end

      def parent_id(context)
        raw = request_hash(context)
        raw[:parent_id].presence || raw["parent_id"].presence
      end

      def request_hash(context)
        params = context.request_params || context.params
        hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        hash.respond_to?(:deep_symbolize_keys) ? hash.deep_symbolize_keys : hash
      end

      def writable_keys(context)
        registration = RecordingStudioApi.recordable_registration_for(
          context.recordable_type,
          api: context.api_key
        )
        Array(registration&.writable_attributes).map(&:to_sym)
      end
    end
  end
end
