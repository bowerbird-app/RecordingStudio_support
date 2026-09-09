# frozen_string_literal: true

RecordingStudioSupport.configure do |config|
  config.pages_path = "/admin/support"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Find an answer."
  config.public_help_title = "Hi, how can we help?"
  config.public_help_subtitle = "Find an answer."
  config.admin_help_title = "Help"
  config.admin_help_subtitle = "Pages people use when they get stuck."
  config.public_section_subtitle = lambda do |section|
    case section.slug
    when "billing"
      "Payments, invoices, and plan changes."
    end
  end
end
