# frozen_string_literal: true

module RecordingStudioSupport
  class SupportPage < ApplicationRecord
    self.table_name = "recording_studio_support_pages"

    recording_studio_recordable label: "Support page",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: %i[image]
    )
    include RecordingStudio::Capabilities::Trashable.to
    include RecordingStudio::Capabilities::Orderable.to(
      allows: ["RecordingStudioAttachable::Attachment"]
    )
    include RecordingStudio::Capabilities::Publishable.to(
      public_controller: "recording_studio_support/public_pages",
      public_action: :show,
      public_layout: "recording_studio/default_layout",
      path: "/help/:uuid/:slug"
    )

    validates :title, presence: true
  end
end
