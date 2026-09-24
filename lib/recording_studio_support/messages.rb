# frozen_string_literal: true

require_relative "messages/staff"
require_relative "messages/open_access_management"
require_relative "messages/desk_access_navigation"

module RecordingStudioSupport
  # Support ↔ Messages desk helpers. Mount parent is Workspace, key `:support`.
  # One MessageGroup per signed-in user under that mount.
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

    def find_or_create_user_group(actor:)
      return if actor.blank?

      mount = ensure_message_mount(actor: actor)
      return if mount.blank?

      user_group_on_mount(mount, actor: actor) || create_user_group!(mount, actor: actor)
    end

    def user_group_on_mount(mount_recording, actor:)
      return if actor.blank? || mount_recording.blank?

      RecordingStudioMessages.viewable_group_recordings(
        actor: actor,
        mount_recording: mount_recording
      ).find { |group| group_owner?(group, actor) }
    end

    def create_user_group!(mount, actor:)
      # First-open must work without Workspace :admin. MessageGroup under a
      # non-shared Workspace cannot use Accessible bootstrap_owner_access!, and
      # Messages create_group still uses grant_access. Open the access-management
      # gate on this thread only (see OpenAccessManagement).
      OpenAccessManagement.with do
        group = RecordingStudioMessages.create_group(
          mount,
          title: group_title_for(actor),
          actor: actor
        )
        sync_staff_grants!(group_recording: group, manager_actor: actor)
        group
      end
    end

    def group_title_for(actor)
      named = actor_label(actor)
      return named if named.present?

      "Support chat"
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
