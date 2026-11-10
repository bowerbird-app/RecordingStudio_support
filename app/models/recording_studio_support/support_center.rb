# frozen_string_literal: true

module RecordingStudioSupport
  class SupportCenter < ApplicationRecord
    self.table_name = "recording_studio_support_centers"

    recording_studio_recordable label: "Support",
                                root: false,
                                allowed_parent_types: [RecordingStudioSupport.parent_root_type]

    RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
    if defined?(RecordingStudioMessages)
      include RecordingStudio::Capabilities::Messages.to(
        keys: [:support],
        membership_locked: [:support]
      )
    end
  end
end
