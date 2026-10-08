# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Registration
      module_function

      PUBLIC_OPERATIONS = %i[index show].freeze
      WRITE_OPERATIONS = %i[create update destroy].freeze
      OPERATIONS_API = :operations

      def register!
        register_public!
        register_operations!
      end

      def register_public!
        register_sections!(api: :public, operations: PUBLIC_OPERATIONS, relationship_endpoints: PUBLIC_OPERATIONS)
        register_pages!(api: :public, operations: PUBLIC_OPERATIONS, capability_actions: [])
      end

      def register_operations!
        register_sections!(
          api: OPERATIONS_API,
          operations: WRITE_OPERATIONS,
          relationship_endpoints: WRITE_OPERATIONS
        )
        register_pages!(
          api: OPERATIONS_API,
          operations: WRITE_OPERATIONS,
          capability_actions: %i[move]
        )
      end

      def register_sections!(api:, operations:, relationship_endpoints:)
        RecordingStudioApi.register_recordable_type_api(
          SECTION_TYPE,
          api: api,
          serializer: Serialize::SECTION,
          output_keys: %i[title slug icon],
          writable_attributes: %i[title icon],
          sortable_attributes: %i[title],
          operations: operations,
          relationships: { pages: pages_relationship(relationship_endpoints) }
        )
      end

      def register_pages!(api:, operations:, capability_actions:)
        RecordingStudioApi.register_recordable_type_api(
          PAGE_TYPE,
          api: api,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          writable_attributes: %i[title description icon body],
          sortable_attributes: %i[title],
          operations: operations,
          capability_actions: capability_actions
        )
      end

      def pages_relationship(endpoints)
        {
          source: :children,
          child_type: PAGE_TYPE,
          many: true,
          include: :request,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          limit: 50,
          endpoints: endpoints
        }
      end
    end
  end
end
