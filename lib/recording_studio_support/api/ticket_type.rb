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
        register_handler(:show, api: :public, handler: TicketShow)
        register_handler(:create, api: :public, handler: TicketOpen)
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
        {
          api: api, serializer: TICKET_SERIALIZER, output_keys: OUTPUT_KEYS,
          writable_attributes: writable_attributes, sortable_attributes: %i[subject],
          operations: operations, capability_actions: [], openapi: openapi
        }
      end

      def register_handler(action, api:, handler:)
        Registration.register_handler(TICKET_TYPE, action, api: api, handler: handler)
      end
    end
  end
end
