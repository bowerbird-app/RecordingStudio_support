# frozen_string_literal: true

module RecordingStudioSupport
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout

    helper_method :current_support_actor, :can_edit_support_pages?

    private

    def current_support_actor
      return Current.actor if defined?(Current) && Current.actor.present?
      return current_user if respond_to?(:current_user)

      nil
    end

    def current_support_root_recording
      return current_root_recording if respond_to?(:current_root_recording)

      nil
    end

    def require_support_root!
      return if current_support_root_recording.present?

      head :not_found
    end

    def authorize_support!(role)
      allowed = support_access_allowed?(role)
      head :forbidden unless allowed
    end

    def can_edit_support_pages?
      support_access_allowed?(:edit)
    end

    def support_access_allowed?(role)
      actor = current_support_actor
      recording = current_support_root_recording
      return false if actor.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: role
      )
    end
  end
end
