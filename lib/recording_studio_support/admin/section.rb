# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class Section < RecordingStudioAdmin::Section
      key "support"
      icon :lifebuoy
      title { RecordingStudioSupport.configuration.admin_help_title }
      subtitle { RecordingStudioSupport.configuration.admin_help_subtitle }

      link :support_pages,
           text: "Support pages",
           url: ->(context) { context.admin_screen_path("support_pages") },
           style: :primary

      link :support_sections,
           text: "Support sections",
           url: ->(context) { context.admin_screen_path("support_sections") },
           style: :secondary

      widget "widgets.support.page_count"
    end
  end
end
