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
  # Signed-in messages desk. Default contact button points here.
  # config.public_contact_href = "/help/messages"
  # Staff set: when set, only this email is staff for grants, desk, and notices.
  # When blank, `messages_admin_finder` runs (default: User.where(admin: true)).
  # config.messages_admin_email = "support@example.com"
  # config.messages_admin_finder = -> { User.where(admin: true) }
end

# Host-owned. Support does not set these. nil falls through to Accessible :edit.
RecordingStudioTrashable.configure do |config|
  config.authorization_resolver = lambda do |actor:, recording:, **|
    RecordingStudioSupport.staff_may_manage?(actor: actor, recording: recording)
  end
end

RecordingStudio::Moveable.configure do |config|
  config.use_builtin_access = true
  config.authorization_hook = lambda do |actor:, source:, destination:, **|
    source_ok = RecordingStudioSupport.staff_may_manage?(actor: actor, recording: source)
    destination_ok = RecordingStudioSupport.staff_may_manage?(actor: actor, recording: destination)
    next true if source_ok && destination_ok

    nil
  end
end
