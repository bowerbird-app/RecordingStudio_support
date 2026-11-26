# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    # A created Message on a ticket group reopens that ticket when the sender is not support team.
    # Registered once, at load, on core after_record. That hook runs inside the message transaction.
    module ReopenOnCustomerMessage
      class << self
        def register!
          return if registered?

          # Core stamps registered_at with Time.zone. The gem loads before Rails sets a zone.
          zone = Time.zone || "UTC"
          Time.use_zone(zone) { RecordingStudio.configuration.hooks.after_record(self) }
          @registered = true
        end

        def registered?
          @registered == true
        end

        def call(event)
          return unless message_created?(event)

          Tickets::ReopenFromCustomerMessage.call(
            group_recording: event.recording.parent_recording,
            actor: event.actor,
            message_recording: event.recording
          )
        end

        private

        def message_created?(event)
          event.action.to_s == "created" &&
            event.recordable_type == RecordingStudioMessages::Message.name
        end
      end
    end
  end
end

RecordingStudioSupport::Messages::ReopenOnCustomerMessage.register!
