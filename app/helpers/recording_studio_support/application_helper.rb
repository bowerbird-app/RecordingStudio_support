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

    def support_page_body_html(body)
      Body.sanitize(body).html_safe
    end

    def support_pages_title
      RecordingStudioSupport.configuration.pages_title
    end

    def support_pages_subtitle
      RecordingStudioSupport.configuration.pages_subtitle
    end

    def support_publish_path(recording)
      engine = publishable_engine_routes
      return if engine.blank? || recording.blank?

      engine.edit_recording_publishable_path(recording_id: recording.id)
    rescue StandardError
      nil
    end

    def support_page_updated_on(time)
      return if time.blank?

      "Updated #{time.to_date.to_fs(:long)}"
    end

    private

    def publishable_engine_routes
      return recording_studio_publishable if respond_to?(:recording_studio_publishable)
      return unless respond_to?(:main_app) && main_app.respond_to?(:recording_studio_publishable)

      main_app.recording_studio_publishable
    end
  end
end
