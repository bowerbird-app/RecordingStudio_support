# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Access
      module_function

      ResolverContext = Struct.new(:controller)

      def admin_root_recording
        return unless defined?(RecordingStudioAdmin)

        resolver = RecordingStudioAdmin.configuration.access_recording_resolver
        return unless resolver

        resolver.call(ResolverContext.new(nil))
      end

      def actor_for(context)
        context.access_grant&.actor
      end

      def can_edit?(context)
        authorized_on_admin_root?(context, :edit)
      end

      def can_view_as_staff?(context)
        authorized_on_admin_root?(context, :view)
      end

      def can_view_workspace?(context, workspace_recording)
        actor = actor_for(context)
        return false if actor.blank? || workspace_recording.blank?

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: workspace_recording,
          role: :view
        )
      end

      def can_view_recording?(context, recording)
        return true if can_view_as_staff?(context)

        can_view_workspace?(context, recording&.root_recording)
      end

      def authorize_edit!(context)
        return if can_edit?(context)

        deny!
      end

      def authorize_view!(context, recording)
        return if can_view_recording?(context, recording)

        deny!
      end

      def deny!
        raise RecordingStudioApi::AuthorizationError, "API access grant is not authorized for this capability"
      end

      def authorized_on_admin_root?(context, role)
        actor = actor_for(context)
        recording = admin_root_recording
        return false if actor.blank? || recording.blank?

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: role
        )
      end
    end
  end
end
