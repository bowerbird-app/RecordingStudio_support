class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  RecordingStudio.enable_capability(:api_access_point, on: self) if defined?(RecordingStudioApi)
  if defined?(RecordingStudioMessages)
    include RecordingStudio::Capabilities::Messages.to(
      keys: [:support],
      membership_locked: [:support]
    )
  end
end
