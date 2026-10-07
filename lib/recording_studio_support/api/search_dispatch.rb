# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module SearchDispatch
      def invoke
        match = resolve_match!
        return super unless support_search_endpoint?(match.endpoint)

        unless request.request_method_symbol == match.endpoint.http_verb
          raise RecordingStudioApi::UnsupportedActionError,
                "#{match.endpoint.name} must be called with #{match.endpoint.http_verb.to_s.upcase}"
        end

        result = match.endpoint.handler.call(endpoint_context(match.endpoint, match.captures))
        result.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
        render json: result.fetch(:json), status: result.fetch(:status, :ok)
      end

      private

      def support_search_endpoint?(endpoint)
        endpoint.name == SEARCH_ENDPOINT.to_s
      end
    end
  end
end
