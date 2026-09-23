# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    module_function

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

    def sync_staff_grants!(group_recording:, manager_actor:)
      return if group_recording.blank? || manager_actor.blank?
      return unless defined?(RecordingStudioAccessible)

      staff_actors.each do |staff|
        next if same_actor?(staff, manager_actor)
        next if staff_has_edit?(group_recording, staff)

        grant_staff_edit!(group_recording, staff, manager_actor)
      end
    end

    def group_owner?(group_recording, actor)
      return false unless defined?(RecordingStudioAccessible)

      # Direct :admin grant only — inherited Workspace :admin must not mark
      # staff as the conversation owner.
      RecordingStudioAccessible.access_recordings_for_actor(
        recording: group_recording,
        actor: actor
      ).any? { |access_recording| access_recording.recordable&.role.to_s == "admin" }
    end

    def staff_has_edit?(group_recording, actor)
      # Direct grant only. Inherited Workspace :edit/:admin must not skip the
      # conversation :edit grant — notifications and desk lists use direct access.
      RecordingStudioAccessible.access_recordings_for_actor(
        recording: group_recording,
        actor: actor
      ).any? do |access_recording|
        %w[edit admin].include?(access_recording.recordable&.role.to_s)
      end
    end

    def already_granted?(group_recording, actor)
      staff_has_edit?(group_recording, actor)
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
