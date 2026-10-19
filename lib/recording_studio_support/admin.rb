# frozen_string_literal: true

require_relative "admin/queries"
require_relative "admin/section"
require_relative "admin/pages_screen"
require_relative "admin/sections_screen"
require_relative "admin/open_tickets_screen"
require_relative "admin/chart_series"
require_relative "admin/duration_axis"
require_relative "admin/time_to_close_screen"
require_relative "admin/help_page_views_screen"
require_relative "admin/widgets"

module RecordingStudioSupport
  module Admin
    module_function

    def register!
      return unless defined?(::RecordingStudioAdmin)

      RecordingStudioAdmin.register_section(Section)
      RecordingStudioAdmin.register_screen(PagesScreen)
      RecordingStudioAdmin.register_screen(SectionsScreen)
      RecordingStudioAdmin.register_screen(OpenTicketsScreen)
      RecordingStudioAdmin.register_screen(TimeToCloseScreen)
      RecordingStudioAdmin.register_screen(HelpPageViewsScreen)
      Widgets::ALL.each { |widget| RecordingStudioAdmin.register_widget(widget) }
    end
  end
end
