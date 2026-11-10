# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    # After Messages send_message, reopen a resolved ticket when the sender is not staff.
    module SendMessageReopen
      def send_message(group_recording:, actor:, **)
        recording = super
        Tickets::ReopenFromCustomerMessage.call(group_recording: group_recording, actor: actor)
        recording
      end

      def self.install!
        return unless defined?(RecordingStudioMessages)
        return if RecordingStudioMessages.singleton_class.ancestors.include?(self)

        RecordingStudioMessages.singleton_class.prepend(self)
      end
    end
  end
end
