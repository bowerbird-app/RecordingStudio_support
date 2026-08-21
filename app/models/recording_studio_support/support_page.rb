# frozen_string_literal: true

module RecordingStudioSupport
  class SupportPage < ApplicationRecord
    self.table_name = "recording_studio_support_pages"

    recording_studio_recordable label: "Support page",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    validates :title, presence: true
  end
end
