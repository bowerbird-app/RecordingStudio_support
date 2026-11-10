# frozen_string_literal: true

RecordingStudioSupport.configure do |config|
  config.pages_path = "<%= options[:mount_path] %>"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Find an answer."
  config.public_help_title = "Hi, how can we help?"
  config.public_help_subtitle = "Find an answer."
  config.admin_help_title = "Support"
  config.admin_help_subtitle = "Pages people use when they get stuck."
  # Signed-in tickets. Default contact button points here.
  # config.public_contact_href = "/help/messages"
  # Parent root for SupportCenter. Set this before models load.
  # config.parent_root_type = "AdminRoot"
end

# Host-owned. Support does not set these. nil falls through to Accessible :edit.
RecordingStudioTrashable.configure do |config|
  config.authorization_resolver = lambda do |actor:, recording:, **|
    RecordingStudioSupport.staff_permission(actor: actor, recording: recording)
  end
end

RecordingStudio::Moveable.configure do |config|
  config.use_builtin_access = true
  config.authorization_hook = lambda do |actor:, source:, destination:, **|
    source_ok = RecordingStudioSupport.staff_permission(actor: actor, recording: source)
    destination_ok = RecordingStudioSupport.staff_permission(actor: actor, recording: destination)
    next true if source_ok && destination_ok

    nil
  end
end
