# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    module PanelHeader
      def self.install!
        prepend_helper(RecordingStudioMessages::PanelHelper) if defined?(RecordingStudioMessages::PanelHelper)
        prepend_helper(RecordingStudioMessages::InboxHelper) if defined?(RecordingStudioMessages::InboxHelper)
      end

      def self.prepend_helper(helper)
        return if helper.ancestors.include?(RecordingStudioSupport::MessagesInboxHelper)

        helper.prepend(RecordingStudioSupport::MessagesInboxHelper)
      end
    end
  end
end
