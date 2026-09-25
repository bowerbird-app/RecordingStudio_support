# frozen_string_literal: true

require_relative "tickets/open"

module RecordingStudioSupport
  # Support tickets wrap a MessageGroup under the Workspace `:support` mount.
  # Tickets own conversation lifecycle; MessageGroups are created per ticket.
  module Tickets
    module_function

    def open!(...)
      Open.call(...)
    end

    def find!(id)
      SupportTicket.find(id)
    end

    def for_message_group_ids(message_group_ids)
      SupportTicket.where(message_group_id: Array(message_group_ids)).order(created_at: :desc)
    end

    def for_actor(actor)
      return SupportTicket.none if actor.blank?

      group_ids = owned_group_recording_ids(actor)
      return SupportTicket.none if group_ids.empty?

      for_message_group_ids(group_ids)
    end

    def owned_group_recording_ids(actor)
      mount = Messages.ensure_message_mount(actor: actor)
      return [] if mount.blank?

      RecordingStudioMessages.viewable_group_recordings(
        actor: actor,
        mount_recording: mount
      ).filter_map do |group|
        group.id if Messages.group_owner?(group, actor)
      end
    end
  end
end
