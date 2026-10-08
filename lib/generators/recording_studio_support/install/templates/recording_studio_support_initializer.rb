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
