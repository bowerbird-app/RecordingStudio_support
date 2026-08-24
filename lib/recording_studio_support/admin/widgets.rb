# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module Widgets
      PAGE_COUNT = RecordingStudioAdmin::Widget.new("widgets.support.page_count") do
        type :number
        title "Support pages"
        value { Queries.kept_page_recordings.count }
        hide_change
        hide_period
      end
    end
  end
end
