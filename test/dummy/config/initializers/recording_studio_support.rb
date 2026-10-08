# frozen_string_literal: true

RecordingStudioSupport.configure do |config|
  config.pages_path = "/admin/support"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Find an answer."
  config.public_help_title = "Hi, how can we help?"
  config.public_help_subtitle = "Find an answer."
  config.admin_help_title = "Support"
  config.admin_help_subtitle = "Pages people use when they get stuck."
  config.public_section_subtitle = lambda do |section|
    case section.slug
    when "billing"
      "Payments, invoices, and plan changes."
    end
  end
  # Default public_contact_href is /help/messages (signed-in desk).
  # Staff set: leave messages_admin_email blank so all User.where(admin: true) are staff.
end

# Host-owned. Support does not set Trashable or Moveable config at boot.
# nil falls through to each gem's built-in Accessible :edit checks.
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
