# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    # Thread-local open gate for first-open MessageGroup grants.
    # Accessible's process-global `access_management_authorizer` must not flip for
    # every Puma thread — only the creating thread may pass while nesting.
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
          return if @installed
          return unless defined?(RecordingStudioAccessible)

          configuration = RecordingStudioAccessible.configuration
          @original = configuration.access_management_authorizer
          configuration.access_management_authorizer = method(:authorize)
          @installed = true
        end

        def authorize(recording:, actor: nil, controller: nil, **)
          return true if open?

          call_original(recording: recording, actor: actor, controller: controller)
        end

        private

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
