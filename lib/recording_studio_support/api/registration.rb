# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Registration
      module_function

      PUBLIC_PAGE_OPERATIONS = %i[index show].freeze
      READ_OPERATIONS = %i[index show].freeze
      WRITE_OPERATIONS = %i[create update destroy].freeze
      ADMIN_PAGE_OPERATIONS = (READ_OPERATIONS + WRITE_OPERATIONS).freeze
      ADMIN_SECTION_OPERATIONS = (READ_OPERATIONS + WRITE_OPERATIONS).freeze
      ADMIN_NESTED_PAGE_OPERATIONS = (READ_OPERATIONS + WRITE_OPERATIONS).freeze
      OPERATIONS_API = :operations

      def register!
        register_public!
        register_operations!
        CenterType.register!
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
          operations: ADMIN_PAGE_OPERATIONS,
          capability_actions: %i[move publish unpublish]
        )
      end

      def register_handlers!
        Handlers.register_reads!
        register_write_handlers!
        Handlers.register_public_refusals!
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
        register_handler(CENTER_TYPE, :create, api: OPERATIONS_API, handler: CreateCenter)
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
          **page_registration_options(api, operations, capability_actions)
        )
      end

      def page_registration_options(api, operations, capability_actions)
        {
          api: api,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          writable_attributes: %i[title description icon body],
          sortable_attributes: %i[title],
          operations: operations,
          capability_actions: capability_actions
        }.merge(page_registration_extra(api))
      end

      def page_registration_extra(api)
        extra = {}
        names = RecordingStudioApi.method(:register_recordable_type_api).parameters.map(&:last)
        extra[:auto_capability_actions] = false if api == :public && names.include?(:auto_capability_actions)
        extra
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
