# frozen_string_literal: true

require_relative "open_access_authorizer_chain"

module RecordingStudioSupport
  module Messages
    # Narrow first-open grant for a Support ticket conversation.
    #
    # Messages +create_group+ grants the opener :admin with +grant_access+.
    # Accessible's default authorizer requires the manager to already hold
    # :admin, so that first owner grant cannot pass. +bootstrap_owner_access!+
    # does not apply under an owned Workspace. This wrap may return true only
    # for the opener, on an empty MessageGroup under the Support mount, while
    # +with+ is active. Every other Accessible check still calls the inner
    # authorizer.
    module OpenAccessManagement
      THREAD_KEY = :recording_studio_support_open_access_management
      MESSAGE_GROUP_TYPE = "RecordingStudioMessages::MessageGroup"

      class << self
        include OpenAccessAuthorizerChain

        def with(actor:, mount:)
          return yield unless defined?(RecordingStudioAccessible)

          install!
          previous = Thread.current[THREAD_KEY]
          Thread.current[THREAD_KEY] = { actor: actor, mount: mount }
          yield
        ensure
          Thread.current[THREAD_KEY] = previous if defined?(RecordingStudioAccessible)
        end

        def open?
          opening_actor.present? && opening_mount.present?
        end

        def authorize(recording:, actor: nil, controller: nil, **)
          return true if first_open_membership_grant?(recording: recording, actor: actor)

          call_original(recording: recording, actor: actor, controller: controller)
        end

        private

        def first_open_membership_grant?(recording:, actor:)
          opener = opening_actor
          mount = opening_mount
          return false unless opener && mount && actor && recording
          return false unless Messages.same_actor?(opener, actor)
          return false unless empty_support_group?(recording, mount)

          true
        end

        def empty_support_group?(recording, mount)
          return false unless recording.respond_to?(:recordable_type)
          return false unless recording.recordable_type == MESSAGE_GROUP_TYPE
          return false unless recording.respond_to?(:parent_recording_id)
          return false unless recording.parent_recording_id == mount.id
          return false if existing_direct_access?(recording)

          true
        end

        def existing_direct_access?(recording)
          RecordingStudioAccessible.access_recordings_for(recording).any?
        rescue StandardError
          true
        end

        def opening_state
          Thread.current[THREAD_KEY]
        end

        def opening_actor
          opening_state.is_a?(Hash) ? opening_state[:actor] : nil
        end

        def opening_mount
          opening_state.is_a?(Hash) ? opening_state[:mount] : nil
        end
      end
    end
  end
end
