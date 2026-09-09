# frozen_string_literal: true

module RecordingStudioSupport
  module ApplicationHelper
    include RecordingStudioSupport::PublicSectionHelper
    include RecordingStudioSupport::ListHelper
    include RecordingStudioSupport::BodyHelper

    def support_page_meta_description(body, description: nil)
      summary = description.to_s.strip.presence
      return summary if summary.present?

      Body.meta_description(body)
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

    def support_public_section_path(recording, **options)
      slug = support_public_section_slug(recording)

      if respond_to?(:main_app) && main_app.respond_to?(:public_help_section_path)
        return main_app.public_help_section_path(slug, **options)
      end

      path = "#{support_public_help_path}/sections/#{slug}"
      return path if options.blank?

      "#{path}?#{options.to_query}"
    end

    def support_public_section_slug(recording)
      recording&.recordable&.slug.presence || recording&.id
    end

    def support_recording_title(recording)
      return unless recording.respond_to?(:recordable)

      recording.recordable&.title
    end

    private

    def publishable_engine_routes
      return recording_studio_publishable if respond_to?(:recording_studio_publishable)
      return unless respond_to?(:main_app) && main_app.respond_to?(:recording_studio_publishable)

      main_app.recording_studio_publishable
    end
  end
end
