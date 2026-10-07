# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Registration
      module_function

      SEARCH_OPENAPI = {
        summary: "Search Support sections and pages",
        description: "Search kept Support sections (title/slug ILIKE) and pages " \
                     "(Pages.apply_query / SupportPage.search). One records array; sections first, then pages. " \
                     "Same Access and per-client search rate limit as GET support_pages?q=. " \
                     "Empty q is a scoped live index of sections and pages and does not count against that limit. " \
                     "List collection ?q= is unchanged.",
        tags: ["Endpoints"],
        parameters: [
          {
            name: "q",
            in: "query",
            required: false,
            schema: { type: "string" },
            description: "Search term. Sections match title/slug ILIKE; pages match title/body trigram. " \
                         "Blank returns the scoped live section+page index."
          },
          {
            name: "limit",
            in: "query",
            required: false,
            schema: { type: "integer" }
          },
          {
            name: "pagination_token",
            in: "query",
            required: false,
            schema: { type: "string" }
          },
          {
            name: "sort",
            in: "query",
            required: false,
            schema: { type: "string" }
          },
          {
            name: "order",
            in: "query",
            required: false,
            schema: { type: "string" }
          }
        ]
      }.freeze

      def register!
        register_sections!
        register_pages!
        register_search!
      end

      def register_sections!
        RecordingStudioApi.register_recordable_type_api(
          SECTION_TYPE,
          serializer: Serialize::SECTION,
          output_keys: %i[title slug icon],
          writable_attributes: %i[title icon],
          sortable_attributes: %i[title],
          operations: %i[index show create update destroy],
          relationships: { pages: pages_relationship }
        )
      end

      def register_pages!
        RecordingStudioApi.register_recordable_type_api(
          PAGE_TYPE,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          writable_attributes: %i[title description icon body],
          sortable_attributes: %i[title],
          operations: %i[index show create update destroy],
          capability_actions: %i[move]
        )
      end

      def register_search!
        return unless RecordingStudioApi.respond_to?(:register_endpoint)
        return if RecordingStudioApi.registered_endpoint(SEARCH_ENDPOINT)

        RecordingStudioApi.register_endpoint(
          SEARCH_ENDPOINT,
          http_verb: :get,
          path: SEARCH_PATH,
          handler: Search,
          openapi: SEARCH_OPENAPI
        )
      end

      def pages_relationship
        {
          source: :children,
          child_type: PAGE_TYPE,
          many: true,
          include: :request,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          limit: 50,
          endpoints: %i[index show create update destroy]
        }
      end
    end
  end
end
