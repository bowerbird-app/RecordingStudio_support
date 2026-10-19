# frozen_string_literal: true

require_relative "admin/queries"
require_relative "admin/section"
require_relative "admin/pages_screen"
require_relative "admin/sections_screen"
require_relative "admin/widgets"

module RecordingStudioSupport
  module Admin
    module_function

    def register!
      return unless defined?(::RecordingStudioAdmin)

      RecordingStudioAdmin.register_section(Section)
      RecordingStudioAdmin.register_screen(PagesScreen)
      RecordingStudioAdmin.register_screen(SectionsScreen)
      Widgets::ALL.each { |widget| RecordingStudioAdmin.register_widget(widget) }
    end
  end
end
