# frozen_string_literal: true

module RecordingStudioSupport
  # Deprecated in 0.25.0. Help page opens are RecordingStudioViews::ViewLog rows.
  # Keep this table until a later release drops recording_studio_support_page_views.
  class PageView < ApplicationRecord
    self.table_name = "recording_studio_support_page_views"

    def self.record!(recording:, actor: nil)
      create!(
        recording_id: recording.id,
        actor_type: actor&.class&.name,
        actor_id: actor&.id
      )
    end
  end
end
