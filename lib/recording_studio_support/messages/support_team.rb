# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    module_function

    def support_team_actors
      support_team_recordings.flat_map { |recording| actors_granted_on(recording) }
                             .uniq { |actor| [actor.class.name, actor.id] }
    end

    def support_team_actor?(actor)
      return false if actor.blank?

      center = SupportCenters.current
      return false if center.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: center,
        role: :edit
      )
    end

    def sync_support_team_grants!(group_recording:, manager_actor:)
      return if group_recording.blank? || manager_actor.blank?
      return unless defined?(RecordingStudioAccessible)

      RecordingStudioMessages.allow_membership_change do
        support_team_actors.each do |teammate|
          next if same_actor?(teammate, manager_actor)
          next if support_team_has_edit?(group_recording, teammate)

          grant_support_team_edit!(group_recording, teammate, manager_actor)
        end
      end
    end

    def group_owner?(group_recording, actor)
      return false unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.access_recordings_for_actor(
        recording: group_recording,
        actor: actor
      ).any? { |access_recording| access_recording.recordable&.role.to_s == "admin" }
    end

    def support_team_has_edit?(group_recording, actor)
      RecordingStudioAccessible.access_recordings_for_actor(
        recording: group_recording,
        actor: actor
      ).any? do |access_recording|
        %w[edit admin].include?(access_recording.recordable&.role.to_s)
      end
    end

    def already_granted?(group_recording, actor)
      support_team_has_edit?(group_recording, actor)
    end

    def grant_support_team_edit!(group_recording, teammate, manager_actor)
      result = RecordingStudioAccessible.grant_access(
        recording: group_recording,
        actor: teammate,
        role: :edit,
        manager_actor: manager_actor
      )
      return if result.success?

      raise RecordingStudioMessages::Error, result.error
    end

    def support_team_recordings
      center = SupportCenters.current
      return [] if center.blank?

      [center, center.parent_recording, center.root_recording].compact.uniq
    end

    def actors_granted_on(recording)
      return [] unless defined?(RecordingStudioAccessible)
      return [] if recording.blank?

      RecordingStudioAccessible.access_recordings_for(recording).filter_map do |access_recording|
        support_team_actor_from(access_recording)
      end
    end

    def support_team_actor_from(access_recording)
      recordable = access_recording.recordable
      return unless support_team_role?(recordable&.role)

      recordable.actor
    end

    def support_team_role?(role)
      %w[edit admin].include?(role.to_s)
    end

    def same_actor?(left, right)
      left.instance_of?(right.class) && left.id.to_s == right.id.to_s
    end
  end
end
