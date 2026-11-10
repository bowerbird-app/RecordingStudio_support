# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    # Narrow first-open grant for a Support ticket conversation.
    #
    # Messages create_group grants the opener :admin with grant_access.
    # Accessible 0.24 also checks RoleCeiling (the manager must already hold
    # the role). This wrap allows only the opener, on an empty MessageGroup
    # under the Support mount, while with is active. Every other Accessible
    # check still uses the inner authorizer and RoleCeiling.
    #
    # Composes under Messages::MembershipLock when that wrap is already installed:
    # MembershipLock → OpenAccess → host. Never wrap MembershipLock as @original
    # (that recurses when MembershipLock re-installs on to_prepare).
    module OpenAccessManagement
      THREAD_KEY = :recording_studio_support_open_access_management
      MESSAGE_GROUP_TYPE = "RecordingStudioMessages::MessageGroup"

      module RoleCeilingFirstOpen
        def allowed?(recording:, manager:, role:)
          return true if OpenAccessManagement.first_open_membership_grant?(
            recording: recording,
            actor: manager
          )

          super
        end
      end

      class << self
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

        def install!
          return unless defined?(RecordingStudioAccessible)

          configuration = RecordingStudioAccessible.configuration
          place_in_authorizer_chain!(
            configuration,
            configuration.access_management_authorizer,
            authorizer_callable
          )
          wrap_role_ceiling!
        end

        def authorize(recording:, actor: nil, controller: nil, **)
          return true if first_open_membership_grant?(recording: recording, actor: actor)

          call_original(recording: recording, actor: actor, controller: controller)
        end

        def first_open_membership_grant?(recording:, actor:)
          opener = opening_actor
          mount = opening_mount
          return false unless opener && mount && actor && recording
          return false unless Messages.same_actor?(opener, actor)
          return false unless empty_support_group?(recording, mount)

          true
        end

        private

        def wrap_role_ceiling!
          return if @role_ceiling_wrapped
          return unless defined?(RecordingStudioAccessible::RoleCeiling)

          RecordingStudioAccessible::RoleCeiling.singleton_class.prepend(RoleCeilingFirstOpen)
          @role_ceiling_wrapped = true
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

        def place_in_authorizer_chain!(configuration, current, callable)
          if current.equal?(callable)
            heal_if_wrapping_membership_lock!(configuration)
          elsif membership_lock_outer?(current)
            insert_under_membership_lock!
          else
            @original = current
            configuration.access_management_authorizer = callable
          end
        end

        def authorizer_callable
          @authorizer_callable ||= method(:authorize)
        end

        def membership_lock_outer?(current)
          return false unless defined?(RecordingStudioMessages::MembershipLock)

          current.equal?(
            RecordingStudioMessages::MembershipLock.instance_variable_get(:@membership_lock_authorizer)
          )
        end

        def insert_under_membership_lock!
          lock = RecordingStudioMessages::MembershipLock
          inner = lock.instance_variable_get(:@membership_lock_inner)
          return if inner.equal?(authorizer_callable)

          @original = inner
          lock.instance_variable_set(:@membership_lock_inner, authorizer_callable)
        end

        def heal_if_wrapping_membership_lock!(configuration)
          return unless defined?(RecordingStudioMessages::MembershipLock)

          lock = RecordingStudioMessages::MembershipLock
          membership_lock = lock.instance_variable_get(:@membership_lock_authorizer)
          return unless @original.equal?(membership_lock)

          host = lock.instance_variable_get(:@membership_lock_inner)
          @original = host.equal?(authorizer_callable) ? nil : host
          lock.instance_variable_set(:@membership_lock_inner, authorizer_callable)
          configuration.access_management_authorizer = membership_lock
        end

        def call_original(recording:, actor:, controller:)
          original = @original
          return false unless original

          original.call(**filtered_kwargs(original, recording:, actor:, controller:))
        rescue ArgumentError
          original.call(recording: recording, actor: actor, controller: controller)
        end

        def filtered_kwargs(original, recording:, actor:, controller:)
          kwargs = { recording: recording, actor: actor, controller: controller }
          return kwargs unless original.respond_to?(:parameters)

          names = original.parameters.filter_map do |type, name|
            name if %i[key keyreq].include?(type)
          end
          names.any? ? kwargs.slice(*names) : kwargs
        end
      end
    end
  end
end
