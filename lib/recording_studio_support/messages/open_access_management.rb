# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    # Thread-local open gate for first-open MessageGroup grants.
    # Accessible's process-global `access_management_authorizer` must not flip for
    # every Puma thread — only the creating thread may pass while nesting.
    #
    # Composes under Messages::MembershipLock when that wrap is already installed:
    # MembershipLock → OpenAccess → host. Never wrap MembershipLock as @original
    # (that recurses when MembershipLock re-installs on to_prepare).
    module OpenAccessManagement
      THREAD_KEY = :recording_studio_support_open_access_management

      class << self
        def with
          return yield unless defined?(RecordingStudioAccessible)

          install!
          previous = Thread.current[THREAD_KEY]
          Thread.current[THREAD_KEY] = true
          yield
        ensure
          Thread.current[THREAD_KEY] = previous if defined?(RecordingStudioAccessible)
        end

        def open?
          Thread.current[THREAD_KEY] == true
        end

        def install!
          return unless defined?(RecordingStudioAccessible)

          configuration = RecordingStudioAccessible.configuration
          place_in_authorizer_chain!(
            configuration,
            configuration.access_management_authorizer,
            authorizer_callable
          )
        end

        def authorize(recording:, actor: nil, controller: nil, **)
          return true if open?

          call_original(recording: recording, actor: actor, controller: controller)
        end

        private

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

        # Recover when we became outermost over MembershipLock (lazy install before
        # this composition fix, or a host that swapped the authorizer).
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
