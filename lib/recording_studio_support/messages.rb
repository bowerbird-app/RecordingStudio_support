# frozen_string_literal: true

require_relative "messages/staff"

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
      # First-open must work without Workspace :admin. Accessible's default
      # access-management authorizer requires :admin on the conversation
      # already, so open the gate only for this create/grant path.
      with_open_access_management do
        group = RecordingStudioMessages.create_group(
          mount,
          title: group_title_for(actor),
          actor: actor
        )
        sync_staff_grants!(group_recording: group, manager_actor: actor)
        group
      end
    end

    def with_open_access_management
      return yield unless defined?(RecordingStudioAccessible)

      configuration = RecordingStudioAccessible.configuration
      original = configuration.access_management_authorizer
      configuration.access_management_authorizer = ->(**) { true }
      yield
    ensure
      configuration.access_management_authorizer = original if configuration
    end

    def group_title_for(actor)
      return actor.name.to_s.strip if actor.respond_to?(:name) && actor.name.present?
      return actor.email.to_s.strip if actor.respond_to?(:email) && actor.email.present?

      "Support chat"
    end
  end
end
