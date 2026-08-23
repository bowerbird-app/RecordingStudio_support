# frozen_string_literal: true

RecordingStudioSupport.configure do |config|
  config.pages_path = "/support"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Find an answer."
  config.public_help_title = "Help"
  config.public_help_subtitle = "Find an answer."
  config.admin_help_title = "Help"
  config.admin_help_subtitle = "Pages people use when they get stuck."
end
