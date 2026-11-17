# frozen_string_literal: true

require_relative "operation_titles"
require_relative "operation_docs"

module RecordingStudioSupport
  module Api
    # MCP 0.36.3 `TypeActions.action_tool` sets the tool title from
    # `ActionDocs.title` (action_docs.rb lines 15-19: the shared action title)
    # and the group from `ToolDocs.action_tags` (tool_docs.rb lines 36-41: the
    # type's openapi tags). Press kits v0.138.0 feeds that with one tag per
    # type and `GlobalActionTitle.stamp` (global_action_title.rb lines 8-11).
    # Trash actions share a type with the other Support actions, so one type
    # tag cannot name both Support and Support Trash. These hooks run after
    # that read and apply Support's own group and title for Support types.
    module McpDocs
      module TitleHook
        def title(action_name, *rest)
          shown = McpDocs.render(rest.last, action_name)
          return shown.fetch(:title) if shown

          super
        end
      end

      module ToolHook
        def action_tool(*args)
          McpDocs.apply_tool(super, args[0], args[1])
        end
      end

      module_function

      def install!
        hook(mcp_constant("RecordingStudioMcp::Documentation::Openapi::ActionDocs"), TitleHook)
        hook(mcp_constant("RecordingStudioMcp::Documentation::Openapi::TypeActions"), ToolHook)
      end

      def entries(api:)
        [PAGE_TYPE, SECTION_TYPE, CENTER_TYPE, TICKET_TYPE].flat_map { |type| entries_for(api, type) }
      end

      def render(type, action)
        title = OperationTitles.capability_title(type, action)
        return if title.nil?

        { group: group_for(action), title: title }
      end

      def apply_tool(tool, entry, action)
        return tool unless tool.is_a?(Hash)

        shown = render(field(entry, :recordable_type), field(action, :name))
        return tool unless shown

        tool.merge("title" => shown.fetch(:title), "tags" => [shown.fetch(:group)])
      end

      def entries_for(api, type)
        return [] unless defined?(RecordingStudioApi)
        return [] unless RecordingStudioApi.recordable_registration_for(type, api: api)

        RecordingStudioApi.capability_actions_for(type, api: api).map do |registered|
          shown = render(type, registered.name) || {}
          { api: api, type: type, action: registered.name.to_sym, group: shown[:group], title: shown[:title] }
        end
      end
      private_class_method :entries_for

      def group_for(action)
        return OperationDocs::TRASH_GROUP if OperationDocs::TRASH_ACTIONS.include?(action.to_sym)

        OperationDocs::GROUP
      end
      private_class_method :group_for

      def field(record, name)
        return unless record.respond_to?(:[])

        record[name.to_s] || record[name.to_sym]
      end
      private_class_method :field

      def hook(target, mod)
        return unless target

        singleton = target.singleton_class
        return if singleton.ancestors.include?(mod)

        singleton.prepend(mod)
      end
      private_class_method :hook

      def mcp_constant(name)
        return unless Object.const_defined?(name)

        Object.const_get(name)
      end
      private_class_method :mcp_constant
    end
  end
end
