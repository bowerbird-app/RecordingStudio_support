# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module SearchDispatch
      def invoke
        match = resolve_match!
        return super unless support_search_endpoint?(match.endpoint)

        assert_search_verb!(match.endpoint)
        render_search_result(dispatch_search(match))
      end

      private

      def support_search_endpoint?(endpoint)
        endpoint.name == SEARCH_ENDPOINT.to_s
      end

      def assert_search_verb!(endpoint)
        return if request.request_method_symbol == endpoint.http_verb

        raise RecordingStudioApi::UnsupportedActionError,
              "#{endpoint.name} must be called with #{endpoint.http_verb.to_s.upcase}"
      end

      def dispatch_search(match)
        match.endpoint.handler.call(endpoint_context(match.endpoint, match.captures))
      end

      def render_search_result(result)
        result.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
        render json: result.fetch(:json), status: result.fetch(:status, :ok)
      end
    end
  end
end
