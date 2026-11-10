# frozen_string_literal: true

require_relative "messages/staff"
require_relative "messages/open_access_management"
require_relative "messages/inbox_access_navigation"
require_relative "messages/panel_header"

module RecordingStudioSupport
  # Support ↔ Messages helpers. Mount parent is SupportCenter, key `:support`.
  # Tickets own conversation lifecycle; MessageGroups are tagged per ticket.
  module Messages
    SUPPORT_MOUNT_KEY = :support

    module_function

    def ensure_message_mount(actor: nil)
      center = SupportCenters.current
      return if center.blank?

      center.ensure_message_mount(SUPPORT_MOUNT_KEY, actor: actor)
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
