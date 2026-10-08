# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Registration
      module_function

      PUBLIC_PAGE_OPERATIONS = %i[index show].freeze
      READ_OPERATIONS = %i[index show].freeze
      WRITE_OPERATIONS = %i[create update destroy].freeze
      ADMIN_SECTION_OPERATIONS = (READ_OPERATIONS + WRITE_OPERATIONS).freeze
      ADMIN_NESTED_PAGE_OPERATIONS = (READ_OPERATIONS + WRITE_OPERATIONS).freeze
      OPERATIONS_API = :operations

      def register!
        register_public!
        register_operations!
        register_handlers!
      end

      def register_public!
        register_pages!(api: :public, operations: PUBLIC_PAGE_OPERATIONS, capability_actions: [])
      end

      def register_operations!
        register_sections!(
          api: OPERATIONS_API,
          operations: ADMIN_SECTION_OPERATIONS,
          relationship_endpoints: ADMIN_NESTED_PAGE_OPERATIONS
        )
        register_pages!(
          api: OPERATIONS_API,
          operations: (READ_OPERATIONS + WRITE_OPERATIONS),
          capability_actions: %i[move publish unpublish]
        )
      end

      def register_handlers!
        register_page_read_handlers!
        register_write_handlers!
        register_public_section_refusals!
      end

      def register_page_read_handlers!
        register_handler(PAGE_TYPE, :index, api: :public, handler: Index)
        register_handler(PAGE_TYPE, :show, api: :public, handler: Show)
        register_handler(SECTION_TYPE, :index, api: OPERATIONS_API, handler: Index)
        register_handler(SECTION_TYPE, :show, api: OPERATIONS_API, handler: Show)
        register_handler(PAGE_TYPE, :index, api: OPERATIONS_API, handler: Index)
        register_handler(PAGE_TYPE, :show, api: OPERATIONS_API, handler: Show)
      end

      def register_write_handlers!
        WRITE_OPERATIONS.each do |action|
          handler = { create: Create, update: Update, destroy: Destroy }.fetch(action)
          [PAGE_TYPE, SECTION_TYPE].each do |type|
            register_handler(type, action, api: OPERATIONS_API, handler: handler)
          end
        end
        register_handler(PAGE_TYPE, :move, api: OPERATIONS_API, handler: Move)
        register_handler(PAGE_TYPE, :publish, api: OPERATIONS_API, handler: Publish)
        register_handler(PAGE_TYPE, :unpublish, api: OPERATIONS_API, handler: Unpublish)
      end

      def register_public_section_refusals!
        %i[index show create update destroy].each do |action|
          register_handler(SECTION_TYPE, action, api: :public, handler: RefusePublicSections)
        end
      end

      def register_handler(type, action, api:, handler:)
        return if RecordingStudioApi.resource_handler(type, action, api: api)

        RecordingStudioApi.register_resource_handler(type, action, api: api, handler: handler)
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
