# frozen_string_literal: true

module RecordingStudioSupport
  module ApplicationHelper
    def support_page_image_url(image_recording)
      file = image_recording.recordable&.file
      return unless file&.attached?

      Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
    end

    def support_page_image_name(image_recording)
      image_recording.recordable&.original_filename.presence || "Image"
    end
  end
end
