# frozen_string_literal: true

require_relative "messages/staff"
require_relative "messages/open_access_management"
require_relative "messages/desk_access_navigation"

module RecordingStudioSupport
  # Support ↔ Messages desk helpers. Mount parent is Workspace, key `:support`.
  # Tickets own conversation lifecycle; MessageGroups are created per ticket.
  module Messages
    SUPPORT_MOUNT_KEY = :support

    module_function

    def ensure_message_mount(actor: nil)
      root = support_workspace_root
      return if root.blank?

      root.ensure_message_mount(SUPPORT_MOUNT_KEY, actor: actor)
    end

    def support_workspace_root
      return unless defined?(RecordingStudioMessages)

      Sections.default_parent_root
    end

    def actor_label(actor)
      return present_string(actor.name) if actor.respond_to?(:name)
      return present_string(actor.display_name) if actor.respond_to?(:display_name)
      return present_string(actor.email) if actor.respond_to?(:email)

      nil
    end

    def present_string(value)
      value.to_s.strip.presence
    end
  end
end
