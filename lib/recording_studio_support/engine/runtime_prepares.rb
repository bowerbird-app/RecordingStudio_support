# frozen_string_literal: true

module RecordingStudioSupport
  class Engine < ::Rails::Engine
    initializer "recording_studio_support.page_nav_compat" do
      config.to_prepare do
        page_nav = FlatPack::PageNav::Component if defined?(FlatPack::PageNav::Component)
        page_nav&.prepend(PageNavCompat) unless page_nav&.ancestors&.include?(PageNavCompat)
        search = defined?(RecordingStudioSearch::InstantSearchesController) &&
                 RecordingStudioSearch::InstantSearchesController
        search&.prepend(SearchInstantLivePages) unless search&.ancestors&.include?(SearchInstantLivePages)
      end
    end

    initializer "recording_studio_support.messages" do
      config.to_prepare do
        RecordingStudioSupport::Engine.register_message_received_with_email!
      end
    end

    def self.register_message_received_with_email!
      return unless defined?(RecordingStudioMessages) && defined?(RecordingStudioNotifications)

      RecordingStudioNotifications.register_notification_type(
        RecordingStudioMessages::MESSAGE_RECEIVED_TYPE,
        label: "Message received",
        description: "A new message arrived in a conversation you can see.",
        icon: :chat_bubble_left, category: :general, scope: :root,
        default_channels: %i[in_app email], available_channels: %i[in_app email]
      )
    end
  end
end
