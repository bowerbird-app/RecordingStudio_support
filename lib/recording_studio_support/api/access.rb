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

      def metrics_admin_root_recording
        return unless defined?(RecordingStudioAdmin)

        config = RecordingStudioAdmin.configuration
        resolver = config.site_admin_recording_resolver || config.access_recording_resolver
        return unless resolver

        begin
          resolver.call(ResolverContext.new(nil))
        rescue StandardError
          nil
        end
      end

      def actor_for(context)
        return context.actor if context.respond_to?(:actor) && context.actor.present?

        context.access_grant&.actor
      end

      def write_actor(context)
        current = defined?(Current) && Current.respond_to?(:actor) ? Current.actor : nil
        return current if person?(current)

        actor_for(context)
      end

      def person?(actor)
        actor.present? && actor.class.name != "RecordingStudioApi::ApiClient"
      end

      def can_edit?(context)
        authorized_on_admin_root?(context, :edit)
      end

      def can_view_as_staff?(context)
        authorized_on_admin_root?(context, :view)
      end

      def can_view_metrics?(context)
        actor = actor_for(context)
        recording = metrics_admin_root_recording
        return false if actor.blank? || recording.blank?

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: :view
        )
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

      def authorize_staff_view!(context)
        return if can_view_as_staff?(context)

        deny!
      end

      def operations_api?(context)
        key = context.respond_to?(:api_key) ? context.api_key : nil
        key.to_s == Registration::OPERATIONS_API.to_s
      end

      def deny!
        raise RecordingStudioApi::AuthorizationError, "API access grant is not authorized for this capability"
      end

      def admin_root_edit?(actor)
        admin_root_authorized?(actor, :edit)
      end

      def authorized_on_admin_root?(context, role)
        admin_root_authorized?(actor_for(context), role)
      end

      def admin_root_authorized?(actor, role)
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
