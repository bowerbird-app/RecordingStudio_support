# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module OperationTitles
      module_function

      def operation_title(type, operation)
        operation_titles.dig(type.to_s, operation.to_sym)
      end

      def capability_title(type, action)
        capability_titles.dig(type.to_s, action.to_sym)
      end

      def operation_titles
        {
          PAGE_TYPE => page_operations,
          SECTION_TYPE => section_operations,
          CENTER_TYPE => center_operations,
          TICKET_TYPE => ticket_operations
        }
      end

      def capability_titles
        {
          PAGE_TYPE => page_actions,
          SECTION_TYPE => section_actions,
          CENTER_TYPE => center_actions
        }
      end

      def page_operations
        {
          index: "List support pages",
          show: "Show support page",
          create: "Create support page",
          update: "Update support page",
          destroy: "Trash support page"
        }
      end

      def section_operations
        {
          index: "List support sections",
          show: "Show support section",
          create: "Create support section",
          update: "Update support section",
          destroy: "Trash support section"
        }
      end

      def center_operations
        {
          index: "List support centers",
          show: "Show support center",
          create: "Create support center"
        }
      end

      def ticket_operations
        {
          index: "List support tickets",
          show: "Show support ticket",
          create: "Open support ticket",
          update: "Update support ticket"
        }
      end

      def page_actions
        {
          move: "Move support page",
          publish: "Publish support page",
          unpublish: "Unpublish support page",
          update_publishable: "Update support page publishing",
          trashable_trash: "Trash support page",
          trashable_restore: "Restore support page",
          trashable_purge: "Purge support trash",
          trashable_list_trash_bin: "List support trash"
        }
      end

      def section_actions
        {
          reorder: "Reorder support section",
          move_position: "Move page in support section",
          trashable_trash: "Trash support section",
          trashable_restore: "Restore support section",
          trashable_purge: "Purge support trash",
          trashable_list_trash_bin: "List support trash"
        }
      end

      def center_actions
        {
          list_access: "List support center access",
          grant_access: "Grant support center access",
          update_access: "Update support center access",
          revoke_access: "Revoke support center access"
        }
      end
    end
  end
end
