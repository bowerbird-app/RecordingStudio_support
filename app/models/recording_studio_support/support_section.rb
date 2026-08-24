# frozen_string_literal: true

module RecordingStudioSupport
  class SupportSection < ApplicationRecord
    self.table_name = "recording_studio_support_sections"

    recording_studio_recordable label: "Help section",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    include RecordingStudio::Capabilities::Trashable.to
    include RecordingStudio::Capabilities::Orderable.to(
      allows: ["RecordingStudioSupport::SupportPage"]
    )

    validates :title, presence: true
  end
end
