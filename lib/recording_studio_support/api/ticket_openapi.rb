# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketOpenapi
      module_function

      STATUS_DESCRIPTION = "Ticket status. Allowed values: open, resolved."
      PRIORITY_DESCRIPTION = "Ticket priority. Allowed values: low, normal, high."
      OPEN_DESCRIPTION =
        "Open a ticket for the Accessible actor on the access grant. Do not send an actor in the body. " \
        "#{PRIORITY_DESCRIPTION}".freeze
      UPDATE_DESCRIPTION =
        "Change status or priority. The actor is the Accessible actor on the access grant. " \
        "#{STATUS_DESCRIPTION} #{PRIORITY_DESCRIPTION}".freeze

      def public
        SUPPORT_OPENAPI.merge(index: index, show: show, create: open)
      end

      def operations
        SUPPORT_OPENAPI.merge(index: index, show: show, update: update)
      end

      def index
        titled(:index, "List tickets the caller can see. Public tokens see the signed-in actor's tickets. " \
                       "A support-team actor's public list is tickets they created. " \
                       "Operations tokens with support-team edit on SupportCenter see every current ticket.")
      end

      def show
        titled(:show, "Return one ticket. Public tokens may read a ticket on their own list. " \
                      "A support-team actor's list is tickets they created. " \
                      "Someone else's ticket is not found. Operations support-team editors can read any ticket. " \
                      "#{STATUS_DESCRIPTION} #{PRIORITY_DESCRIPTION}")
      end

      def open
        titled(:create, OPEN_DESCRIPTION, request_body: open_body)
      end

      def update
        titled(:update, UPDATE_DESCRIPTION, request_body: update_body)
      end

      def titled(operation, description, request_body: nil)
        title = OperationDocs.operation_title(TICKET_TYPE, operation)
        copy = { title: title, summary: title, description: description }
        copy[:request_body] = request_body if request_body
        copy
      end

      def open_body
        write_body(
          {
            subject: { type: "string", description: "Short subject for the ticket and its conversation." },
            body: { type: "string", description: "First message posted on the ticket thread." },
            priority: { type: "string", enum: SupportTicket::PRIORITIES, description: PRIORITY_DESCRIPTION }
          },
          required: %w[subject body]
        )
      end

      def update_body
        write_body(
          {
            status: { type: "string", enum: SupportTicket::STATUSES, description: STATUS_DESCRIPTION },
            priority: { type: "string", enum: SupportTicket::PRIORITIES, description: PRIORITY_DESCRIPTION }
          }
        )
      end

      def write_body(properties, required: [])
        schema = { type: "object", properties: properties }
        schema[:required] = required if required.any?
        { content: { "application/json" => { schema: schema } } }
      end
    end
  end
end
