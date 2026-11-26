# frozen_string_literal: true

module RecordingStudioSupportDummy
  module RecordingStudioWritePolicy
    module_function

    def allowed?(actor:, root_recording:, recordable:, recording: nil, parent_recording: nil, **)
      return false if actor.blank?
      return root_create_allowed?(actor, recordable) if root_recording.blank? && parent_recording.blank?
      return false if root_recording.blank?

      if follow_recordable?(recordable)
        target = parent_recording || root_recording
        return false if target.blank?

        return RecordingStudioAccessible.authorized?(actor: actor, recording: target, role: :view)
      end

      if defined?(RecordingStudio::Access) && recordable.is_a?(RecordingStudio::Access)
        return true if RecordingStudioAccessible::AccessCreationContext.allowed?

        return RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: root_recording,
          role: :admin
        )
      end

      return trusted_message_write?(recordable) if message_recordable?(recordable)

      return true if shared_root_write?(actor, root_recording, recordable, recording)

      [root_recording, parent_recording, recording].each do |target|
        next if target.blank?
        return true if RecordingStudioAccessible.authorized?(actor: actor, recording: target, role: :edit)
      end

      return true if api_client_self_write?(actor, recordable) &&
                     RecordingStudioAccessible.authorized?(
                       actor: actor,
                       recording: root_recording,
                       role: :view
                     )

      return true if support_inbox_write?(actor, recordable, recording, parent_recording)

      false
    end

    def root_create_allowed?(actor, recordable)
      return false unless actor.respond_to?(:persisted?) && actor.persisted?
      return false if recordable.blank?

      RecordingStudio::RecordableDeclarations.root_allowed?(recordable)
    end

    def follow_recordable?(recordable)
      defined?(RecordingStudioFollowable::Follow) && recordable.is_a?(RecordingStudioFollowable::Follow)
    end

    def shared_root_write?(actor, root_recording, recordable, recording)
      return false unless RecordingStudio.shared_root?(root_recording)
      return false unless actor.respond_to?(:persisted?) && actor.persisted?

      own_people_profile?(actor, recordable, recording) || new_terms_document?(recordable, recording)
    end

    def own_people_profile?(actor, recordable, recording)
      return false unless defined?(RecordingStudioUser::Profile)
      return false unless recordable.is_a?(RecordingStudioUser::Profile)
      return false unless profile_owner?(actor, recordable)

      existing = recording&.recordable
      return true if existing.nil?

      existing.is_a?(RecordingStudioUser::Profile) && profile_owner?(actor, existing)
    end

    def profile_owner?(actor, profile)
      return false unless actor.is_a?(User)
      return false if profile.user_id.blank?

      profile.user_id == actor.id
    end

    def new_terms_document?(recordable, recording)
      return false unless recording.nil?
      return false unless defined?(RecordingStudioTermsAndConditions::Terms)

      recordable.is_a?(RecordingStudioTermsAndConditions::Terms)
    end

    def api_client_self_write?(actor, recordable)
      return false unless defined?(RecordingStudioApi::ApiClient)
      return false unless actor.is_a?(RecordingStudioApi::ApiClient) && actor.persisted?

      recordable.is_a?(RecordingStudioApi::ApiClient) ||
        recordable.is_a?(RecordingStudioApi::ApiCredential) ||
        (defined?(RecordingStudioApi::ApiAccessToken) && recordable.is_a?(RecordingStudioApi::ApiAccessToken))
    end

    def message_recordable?(recordable)
      return false unless defined?(RecordingStudioMessages::MessageGroup)

      recordable.is_a?(RecordingStudioMessages::MessageGroup) ||
        recordable.is_a?(RecordingStudioMessages::Message)
    end

    def trusted_message_write?(recordable)
      return false unless message_recordable?(recordable)
      return false unless defined?(RecordingStudioMessages.trusted_write_context)

      context = RecordingStudioMessages.trusted_write_context
      return false if context.nil?

      action = context.action
      return true if action == :send_message && recordable.is_a?(RecordingStudioMessages::Message)
      return true if action == :create_group && recordable.is_a?(RecordingStudioMessages::MessageGroup)
      return true if action == :rename_group && recordable.is_a?(RecordingStudioMessages::MessageGroup)

      false
    end

    def support_inbox_write?(actor, recordable, recording, parent_recording)
      return false unless defined?(RecordingStudioSupport::SupportCenter)
      return false if recording.present?
      return false unless actor.respond_to?(:persisted?) && actor.persisted?
      return false if parent_recording.blank?
      return false unless parent_recording.recordable.is_a?(RecordingStudioSupport::SupportCenter)

      recordable.is_a?(RecordingStudioSupport::SupportTicket) ||
        (defined?(RecordingStudioMessages::MessageMount) &&
          recordable.is_a?(RecordingStudioMessages::MessageMount))
    end
  end
end
