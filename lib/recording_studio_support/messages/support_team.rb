# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    module_function

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
  end
end
