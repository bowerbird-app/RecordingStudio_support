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

    def support_help_title
      RecordingStudioSupport.configuration.help_title
    end

    def support_help_subtitle
      RecordingStudioSupport.configuration.help_subtitle
    end

    def support_public_help_title
      RecordingStudioSupport.configuration.public_help_title
    end

    def support_public_help_subtitle
      RecordingStudioSupport.configuration.public_help_subtitle
    end

    def support_public_help_path
      return main_app.public_help_path if respond_to?(:main_app) && main_app.respond_to?(:public_help_path)

      RecordingStudioSupport.configuration.public_pages_path
    end

    def support_public_section_path(recording)
      if respond_to?(:main_app) && main_app.respond_to?(:public_help_section_path)
        return main_app.public_help_section_path(recording)
      end

      "#{support_public_help_path}/sections/#{recording.id}"
    end

    def support_section_options(section_recordings)
      Array(section_recordings).filter_map do |recording|
        title = recording.recordable&.title
        next if title.blank?

        [title, recording.id]
      end
    end

    private

    def publishable_engine_routes
      return recording_studio_publishable if respond_to?(:recording_studio_publishable)
      return unless respond_to?(:main_app) && main_app.respond_to?(:recording_studio_publishable)

      main_app.recording_studio_publishable
    end
  end
end
