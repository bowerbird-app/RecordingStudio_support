# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class Section < RecordingStudioAdmin::Section
      key "support"
      icon :lifebuoy
      title { RecordingStudioSupport.configuration.admin_help_title }
      subtitle { RecordingStudioSupport.configuration.admin_help_subtitle }

      link :page_list,
           text: "See every page",
           url: ->(context) { context.admin_screen_path("help_pages") },
           style: :primary

      widget "widgets.support.sections"
      widget "widgets.support.recent_pages"
    end
  end
end
