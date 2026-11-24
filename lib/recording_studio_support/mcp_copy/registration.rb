# frozen_string_literal: true

module RecordingStudioSupport
  module McpCopy
    module Registration
      module_function

      def register!
        register_types
        register_named_operations
        register_named_actions
        register_search
        register_message_tools
        register_close_tool
      end

      def register_types
        return unless ::RecordingStudioMcp.respond_to?(:register_type)

        TypeDescriptions::BY_TYPE.each do |type, description|
          ::RecordingStudioMcp.register_type(type: type, description: description)
        end
      end

      def register_named_operations
        (PUBLIC_OPERATIONS + OPERATIONS_OPERATIONS).uniq.each do |type, verb|
          register_tool(type, verb, operation: verb)
        end
      end

      def register_named_actions
        OPERATIONS_ACTIONS.each { |type, verb| register_tool(type, verb, action: verb) }
      end

      def register_search
        ::RecordingStudioMcp.register_tool(
          name: SEARCH, endpoint: SEARCH.to_sym, type: PAGE,
          title: SEARCH_COPY.fetch(:title), description: SEARCH_COPY.fetch(:description),
          input: { "q" => { description: Api::Search::QUERY } }, output: SEARCH_OUTPUT
        )
      end

      def register_message_tools
        Api::TicketMessages::NAMES.each do |name|
          copy = Api::TicketMessages::Copy.copy_for(name)
          ::RecordingStudioMcp.register_tool(
            name: name.to_s, endpoint: name, title: copy.fetch(:title),
            description: copy.fetch(:description), input: message_input(name),
            output: MESSAGE_OUTPUTS.fetch(name.to_s)
          )
        end
      end

      def register_tool(type, verb, **target)
        ::RecordingStudioMcp.register_tool(
          name: McpCopy.tool_name(type, verb), type: type, **target,
          title: OperationDescriptions.title_for(type, verb),
          description: OperationDescriptions.description_for(type, verb),
          input: tool_input(type, verb), output: OperationDescriptions.output_for(type, verb)
        )
      end

      def register_close_tool
        ::RecordingStudioMcp.register_tool(
          name: CLOSE, endpoint: Api::TicketClose::NAME,
          title: TicketOperationCopy.close_title,
          description: TicketOperationCopy.close_description,
          input: { "id" => { description: Api::TicketMessages::TICKET_ID } },
          output: "The support ticket after it is resolved."
        )
      end

      def tool_input(type, verb)
        return open_ticket_input if type.to_s == TICKET && verb.to_sym == :create

        {}
      end

      def open_ticket_input
        schema = Api::TicketOpenapi.open_body.dig(:content, "application/json", :schema)
        required = Array(schema.fetch(:required)).map(&:to_s)
        schema.fetch(:properties).to_h { |name, property| [name.to_s, input_field(property, required, name)] }
      end

      def input_field(property, required, name)
        field = input_field_base(property, required, name)
        field[:enum] = property[:enum] if property[:enum]
        field
      end

      def input_field_base(property, required, name)
        {
          type: property.fetch(:type),
          required: required.include?(name.to_s),
          description: property.fetch(:description)
        }
      end

      def message_input(name)
        return {} if name == Api::TicketMessages::UNREAD_COUNT

        fields = { "id" => { description: Api::TicketMessages::TICKET_ID } }
        fields["body"] = { description: Api::TicketMessages::BODY } if name == Api::TicketMessages::REPLY
        fields
      end
    end
  end
end
