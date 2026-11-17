# frozen_string_literal: true

require_relative "operation_titles"

module RecordingStudioSupport
  module Api
    module OperationDocs
      GROUP = "Support"
      TRASH_GROUP = "Support Trash"
      TRASH_ACTIONS = %i[
        trashable_trash trashable_restore trashable_purge trashable_list_trash_bin
      ].freeze
      APIS = %i[public operations].freeze

      module_function

      def for(type, operations:)
        Array(operations).each_with_object(SUPPORT_OPENAPI.dup) do |operation, copy|
          assign_operation(copy, type, operation)
        end
      end

      def apply_capability_titles!
        return unless defined?(RecordingStudioApi)

        APIS.each { |api| apply_api(api) }
        McpDocs.install!
      end

      def operation_title(type, operation)
        OperationTitles.operation_title(type, operation)
      end

      def capability_title(type, action)
        OperationTitles.capability_title(type, action)
      end

      def capability_titles
        OperationTitles.capability_titles
      end

      def assign_operation(copy, type, operation)
        title = operation_title(type, operation)
        return if title.nil?

        copy[operation.to_sym] = operation_hash(type, operation, title)
      end
      private_class_method :assign_operation

      def operation_hash(type, operation, title)
        copy = { title: title, summary: title }
        description = destroy_description(type, operation)
        copy[:description] = description if description
        copy
      end
      private_class_method :operation_hash

      def destroy_description(type, operation)
        return unless operation.to_sym == :destroy

        {
          PAGE_TYPE => "Moves this support page to the trash.",
          SECTION_TYPE => "Moves this support section to the trash."
        }[type.to_s]
      end
      private_class_method :destroy_description

      def apply_api(api)
        capability_titles.each_value do |titles|
          titles.each_key { |name| install(RecordingStudioApi.capability_action(name, api: api)) }
        end
      end
      private_class_method :apply_api

      def install(action)
        return if action.nil? || action.instance_variable_get(:@support_operation_docs)

        current = action.instance_variable_get(:@per_type_openapi)
        action.instance_variable_set(:@per_type_openapi, wrapper(current))
        action.instance_variable_set(:@support_operation_docs, true)
      end
      private_class_method :install

      def wrapper(current)
        lambda do |type:, action:|
          base = callable_copy(current, type, action)
          extra = capability_copy(type, action)
          merge_copy(base, extra)
        end
      end
      private_class_method :wrapper

      def callable_copy(current, type, action)
        return unless current.respond_to?(:call)

        current.call(type: type, action: action)
      end
      private_class_method :callable_copy

      def capability_copy(type, action)
        title = capability_title(type, action)
        return if title.nil?

        copy = { title: title, summary: title }
        return copy unless TRASH_ACTIONS.include?(action.to_sym)

        copy.merge(tags: [TRASH_GROUP], tag: { group: TRASH_GROUP })
      end
      private_class_method :capability_copy

      def merge_copy(base, extra)
        return extra if base.nil?
        return base if extra.nil?

        base.merge(extra)
      end
      private_class_method :merge_copy
    end
  end
end
