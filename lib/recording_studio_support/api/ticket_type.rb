# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketType
      module_function

      TICKET_SERIALIZER = lambda { |ticket, **|
        {
          subject: ticket.subject,
          status: ticket.status,
          priority: ticket.priority,
          resolved_at: ticket.resolved_at&.iso8601
        }
      }

      OUTPUT_KEYS = %i[subject status priority resolved_at].freeze

      def register!
        register_public!
        register_operations!
      end

      def register_public!
        register_type(
          api: :public,
          writable_attributes: %i[subject body priority],
          operations: %i[index show create],
          openapi: TicketOpenapi.public
        )
        register_handler(:index, api: :public, handler: TicketIndex)
        register_handler(:show, api: :public, handler: TicketShow, owns_scoping: true)
        register_handler(:create, api: :public, handler: TicketOpen, parent: :server)
      end

      def register_operations!
        register_type(
          api: Registration::OPERATIONS_API,
          writable_attributes: %i[status priority],
          operations: %i[index show update],
          openapi: TicketOpenapi.operations
        )
        register_handler(:index, api: Registration::OPERATIONS_API, handler: TicketIndex)
        register_handler(:show, api: Registration::OPERATIONS_API, handler: TicketShow)
        register_handler(:update, api: Registration::OPERATIONS_API, handler: TicketUpdate)
      end

      def register_type(api:, writable_attributes:, operations:, openapi:)
        RecordingStudioApi.register_recordable_type_api(TICKET_TYPE, **type_options(
          api: api, writable_attributes: writable_attributes, operations: operations, openapi: openapi
        ))
      end

      def type_options(api:, writable_attributes:, operations:, openapi:)
        options = {
          api: api, serializer: TICKET_SERIALIZER, output_keys: OUTPUT_KEYS,
          writable_attributes: writable_attributes, sortable_attributes: %i[subject],
          operations: operations, capability_actions: [], openapi: openapi
        }
        options[:auto_capability_actions] = false if api == :public
        options
      end

      def register_handler(action, api:, handler:, owns_scoping: false, parent: nil)
        unless parent && server_parent_supported?
          return Registration.register_handler(TICKET_TYPE, action, api:, handler:, owns_scoping:)
        end

        return if RecordingStudioApi.resource_handler(TICKET_TYPE, action, api: api)

        RecordingStudioApi.register_resource_handler(
          TICKET_TYPE, action, api:, handler:, owns_scoping:, parent:
        )
      end

      def server_parent_supported?
        return false unless defined?(RecordingStudioApi)
        return false unless RecordingStudioApi.respond_to?(:register_resource_handler)

        RecordingStudioApi.method(:register_resource_handler).parameters.any? { |_, name| name == :parent }
      end
    end
  end
end
