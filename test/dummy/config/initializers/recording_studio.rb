# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "AdminRoot",
    "RecordingStudioSupport::SupportCenter",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioSupport::SupportSection",
    "RecordingStudioSupport::SupportPage",
    "RecordingStudioSupport::SupportTicket",
    "RecordingStudioMessages::MessageMount",
    "RecordingStudioMessages::MessageGroup",
    "RecordingStudioMessages::Message",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudioPublishable::Publishable",
    "RecordingStudio::Access",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioApi::ApiCredential",
    "RecordingStudioApi::ApiAccessToken",
    "RecordingStudioApi::AdminApi"
  ]

  config.require_recordable_declarations = true

  config.app_name = "Dummy host" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  # Recording Studio 6.5 refuses writes with no authorizer. Dummy seeds and
  # tests record help before Accessible grants exist, so this host keeps the
  # previous open writes. A production host sets authorize_write instead.
  config.allow_unauthorized_writes = true

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
