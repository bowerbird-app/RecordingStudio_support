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
          input: {}, output: OperationDescriptions.output_for(type, verb)
        )
      end

      def message_input(name)
        return { "body" => { description: Api::TicketMessages::BODY } } if name == Api::TicketMessages::REPLY

        {}
      end
    end
  end
end
