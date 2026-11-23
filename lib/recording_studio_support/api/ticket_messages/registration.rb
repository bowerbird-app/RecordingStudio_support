# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketMessages
      module Registration
        module_function

        def register!
          return unless defined?(RecordingStudioApi)

          APIS.each { |api| register_api!(api) }
        end

        def register_api!(api)
          register_member!(LIST, api: api, verb: :get, path: "support_ticket_messages/:id", handler: List)
          register_member!(
            REPLY, api: api, verb: :post, path: "support_ticket_reply/:id", handler: Reply, fields: reply_fields
          )
          register_member!(MARK_READ, api: api, verb: :post, path: "support_ticket_mark_read/:id", handler: MarkRead)
          register_count!(api)
        end

        def reply_fields
          { body: { type: :string, required: true, allow_blank: false, description: BODY } }
        end

        def register_member!(name, **spec)
          api = spec.fetch(:api)
          return if RecordingStudioApi.registered_endpoint(name, api: api)

          RecordingStudioApi.register_endpoint(name, **endpoint_options(name, spec))
        end

        def register_count!(api)
          return if RecordingStudioApi.registered_endpoint(UNREAD_COUNT, api: api)

          RecordingStudioApi.register_endpoint(
            UNREAD_COUNT, api: api, http_verb: :get, path: "support_ticket_unread_count",
                          handler: UnreadCount, input_contract: { reject_unknown: false, fields: {} },
                          openapi: count_openapi
          )
        end

        def endpoint_options(name, spec)
          api = spec.fetch(:api)
          options = {
            api: api, http_verb: spec.fetch(:verb), path: spec.fetch(:path), handler: spec.fetch(:handler),
            input_contract: { reject_unknown: false, fields: spec[:fields] || {} },
            openapi: member_openapi(name)
          }
          options[:recordable_type] = TICKET_TYPE if api == Api::Registration::OPERATIONS_API
          options[:scope_id] = false if api == :public
          options
        end

        def member_openapi(name)
          copy = Copy.copy_for(name)
          OPENAPI.merge(
            title: copy.fetch(:title), summary: copy.fetch(:title),
            description: copy.fetch(:description),
            parameters: [{
              name: "id", in: "path", required: true,
              schema: { type: "string" }, description: TICKET_ID
            }]
          )
        end

        def count_openapi
          copy = Copy.copy_for(UNREAD_COUNT)
          OPENAPI.merge(title: copy.fetch(:title), summary: copy.fetch(:title), description: copy.fetch(:description))
        end
      end
    end
  end
end
