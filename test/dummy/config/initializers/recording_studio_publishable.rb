# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  # Staff publish screens stay on Recording Studio's default layout.
  # Public help uses Publishable's public layout via SupportPage `.to`.
  config.layout = "recording_studio/default_layout"

  config.management_authorizer = lambda do |recording:, actor:, **|
    actor.present? &&
      recording.present? &&
      defined?(RecordingStudioAccessible) &&
      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
  end

  config.management_close_url_resolver = lambda do |controller:, recording:, **|
    if recording.present? && controller.respond_to?(:recording_studio_support)
      controller.recording_studio_support.page_path(recording)
    elsif controller.respond_to?(:main_app) && controller.main_app.respond_to?(:root_path)
      controller.main_app.root_path
    else
      "/"
    end
  end
end
