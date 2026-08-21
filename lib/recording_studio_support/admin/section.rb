# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    class Section < RecordingStudioAdmin::Section
      key "support"
      icon :lifebuoy
      title { RecordingStudioSupport.configuration.admin_section_title }
      subtitle { RecordingStudioSupport.configuration.admin_section_subtitle }

      link :open_pages,
           text: "Open help pages",
           url: ->(_context) { RecordingStudioSupport.configuration.pages_path },
           style: :primary
      link :page_list,
           text: "See every page",
           url: ->(context) { context.admin_screen_path("help_pages") },
           style: :secondary

      widget "widgets.support.page_count", view_variant: :compact
      widget "widgets.support.page_views", view_variant: :compact
      widget "widgets.support.recent_pages"
    end
  end
end
