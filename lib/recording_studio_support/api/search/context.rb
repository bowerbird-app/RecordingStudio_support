# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Search
      class Context
        def initialize(endpoint_context)
          @endpoint_context = endpoint_context
        end

        def resource_name
          RESOURCE_NAME
        end

        def api_version
          "v1"
        end

        def api_client
          @endpoint_context.api_client
        end

        def access_grant
          @endpoint_context.access_grant
        end

        def params
          @endpoint_context.params
        end

        def api_key
          @endpoint_context.api_key
        end
      end
    end
  end
end
