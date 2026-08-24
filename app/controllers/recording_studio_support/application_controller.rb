# frozen_string_literal: true

module RecordingStudioSupport
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout

    helper_method :current_support_actor, :can_edit_support_pages?

    ResolverContext = Struct.new(:controller)

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
      return false if actor.blank?

      recordings_for_support_authorization.any? do |recording|
        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: role
        )
      end
    end

    def recordings_for_support_authorization
      [
        @page_recording&.root_recording,
        @section_recording&.root_recording,
        current_support_root_recording,
        admin_access_recording
      ].compact.uniq
    end

    def admin_access_recording
      return unless defined?(RecordingStudioAdmin)

      resolver = RecordingStudioAdmin.configuration.access_recording_resolver
      return unless resolver

      resolver.call(ResolverContext.new(self))
    end

    def page_parent_section_recording
      section_id = params.dig(:page, :section_id).presence || params[:section_id]
      return Sections.find_kept!(id: section_id) if section_id.present?

      Pages.default_section_for(current_support_root_recording)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def section_parent_root_recording
      Sections.parent_root_for(current_support_root_recording)
    end
  end
end
