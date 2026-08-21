# frozen_string_literal: true

module RecordingStudioSupport
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
