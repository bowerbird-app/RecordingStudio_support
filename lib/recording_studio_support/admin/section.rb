# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class Section < RecordingStudioAdmin::Section
      key "support"
      icon :lifebuoy
      title { RecordingStudioSupport.configuration.admin_help_title }
      subtitle { RecordingStudioSupport.configuration.admin_help_subtitle }
      blast_radius :site

      link :support_pages,
           text: "Support pages",
           url: ->(context) { context.admin_screen_path("support_pages") },
           style: :primary

      link :support_sections,
           text: "Support sections",
           url: ->(context) { context.admin_screen_path("support_sections") },
           style: :secondary

      widget "widgets.support.page_count"
      widget "widgets.support.unassigned_open"
      widget "widgets.support.oldest_open_age"
      widget "widgets.support.avg_time_to_resolve"
      widget "widgets.support.page_views"
    end
  end
end
