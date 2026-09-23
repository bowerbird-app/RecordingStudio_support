# frozen_string_literal: true

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

    def staff_actors
      email = RecordingStudioSupport.configuration.messages_admin_email.to_s.strip
      return Array(find_user_by_email(email)).compact if email.present?

      finder = RecordingStudioSupport.configuration.messages_admin_finder
      return Array(finder.call).compact if finder.respond_to?(:call)

      default_admin_users
    end

    def staff_actor?(actor)
      return false if actor.blank?

      staff_actors.any? { |staff| same_actor?(staff, actor) }
    end

    def find_or_create_user_group(actor:)
      return if actor.blank?

      mount = ensure_message_mount(actor: actor)
      return if mount.blank?

      existing = user_group_on_mount(mount, actor: actor)
      return existing if existing

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

    def user_group_on_mount(mount_recording, actor:)
      return if actor.blank? || mount_recording.blank?

      RecordingStudioMessages.viewable_group_recordings(
        actor: actor,
        mount_recording: mount_recording
      ).find { |group| group_owner?(group, actor) }
    end

    def sync_staff_grants!(group_recording:, manager_actor:)
      return if group_recording.blank? || manager_actor.blank?
      return unless defined?(RecordingStudioAccessible)

      staff_actors.each do |staff|
        next if same_actor?(staff, manager_actor)
        next if already_granted?(group_recording, staff)

        grant_staff_edit!(group_recording, staff, manager_actor)
      end
    end

    def group_owner?(group_recording, actor)
      return false unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: group_recording,
        role: :admin
      )
    end

    def already_granted?(group_recording, actor)
      RecordingStudioAccessible.access_recordings_for_actor(
        recording: group_recording,
        actor: actor
      ).any?
    end

    def grant_staff_edit!(group_recording, staff, manager_actor)
      result = RecordingStudioAccessible.grant_access(
        recording: group_recording,
        actor: staff,
        role: :edit,
        manager_actor: manager_actor
      )
      return if result.success?

      raise RecordingStudioMessages::Error, result.error
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

    def find_user_by_email(email)
      return if email.blank?
      return unless defined?(User)
      return unless User.respond_to?(:find_by)

      User.find_by(email: email)
    end

    def default_admin_users
      return [] unless defined?(User)
      return [] unless User.respond_to?(:where)
      return [] unless User.column_names.include?("admin")

      User.where(admin: true).to_a
    end

    def same_actor?(left, right)
      left.instance_of?(right.class) && left.id.to_s == right.id.to_s
    end
  end
end
