# frozen_string_literal: true

require_relative "mcp_copy/type_descriptions"
require_relative "mcp_copy/operation_descriptions"
require_relative "mcp_copy/registration"

module RecordingStudioSupport
  # Registers Support named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
    PAGE = Api::PAGE_TYPE
    SECTION = Api::SECTION_TYPE
    CENTER = Api::CENTER_TYPE
    TICKET = Api::TICKET_TYPE
    SEARCH = Api::Search::NAME.to_s
    MESSAGE_NAMES = Api::TicketMessages::NAMES.map(&:to_s).freeze

    PUBLIC_OPERATIONS = [
      [PAGE, :index], [PAGE, :show], [TICKET, :index], [TICKET, :show], [TICKET, :create]
    ].freeze
    OPERATIONS_OPERATIONS = [
      [CENTER, :index], [CENTER, :show], [CENTER, :create],
      [SECTION, :index], [SECTION, :show], [SECTION, :create], [SECTION, :update],
      [PAGE, :index], [PAGE, :show], [PAGE, :create], [PAGE, :update],
      [TICKET, :index], [TICKET, :show], [TICKET, :update]
    ].freeze
    OPERATIONS_ACTIONS = [[PAGE, :move], [PAGE, :publish], [PAGE, :unpublish]].freeze
    SEARCH_COPY = {
      title: Api::Search::TITLE,
      description:
        "Search published support pages by title and body. Pass q as the text to match. " \
        "#{TypeDescriptions::PAGE} Drafts are left out of the result."
    }.freeze
    SEARCH_OUTPUT = "Matching published support pages."
    MESSAGE_OUTPUTS = {
      "list_support_ticket_messages" => "The messages on that ticket, oldest first.",
      "reply_to_support_ticket" => "The new message.",
      "mark_support_ticket_read" => "The support ticket after it is marked read.",
      "count_unread_support_tickets" => "unread_count for the signed-in person."
    }.freeze
    TOOL_NAME_OVERRIDES = { [TICKET, :create] => "open_support_ticket" }.freeze

    module_function

    def register!
      return unless defined?(::RecordingStudioMcp)
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      Registration.register!
    end

    def tool_names(api: nil)
      case api&.to_sym
      when :public then public_tool_names
      when :operations then operations_tool_names
      else (public_tool_names + operations_tool_names).uniq
      end
    end

    def public_tool_names
      PUBLIC_OPERATIONS.map { |type, verb| tool_name(type, verb) } + [SEARCH] + MESSAGE_NAMES
    end

    def operations_tool_names
      OPERATIONS_OPERATIONS.map { |type, verb| tool_name(type, verb) } +
        OPERATIONS_ACTIONS.map { |type, verb| tool_name(type, verb) } +
        MESSAGE_NAMES
    end

    def tool_name(type, verb)
      TOOL_NAME_OVERRIDES[[type, verb]] || begin
        action = verb.to_sym == :index ? "list" : verb.to_s
        noun = type.to_s.split("::").last.underscore
        "#{action}_#{action == 'list' ? noun.pluralize : noun}"
      end
    end
  end
end
