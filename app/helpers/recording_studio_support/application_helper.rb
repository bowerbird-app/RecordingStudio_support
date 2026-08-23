# frozen_string_literal: true

module RecordingStudioSupport
  module ApplicationHelper
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

    def support_recording_title(recording)
      return unless recording.respond_to?(:recordable)

      recording.recordable&.title
    end

    def support_list_chevron
      render FlatPack::Shared::IconComponent.new(name: "chevron-right", size: :md)
    end

    def support_page_count_label(page_count)
      page_count.to_s
    end

    def support_page_count_badge(page_count)
      render FlatPack::Badge::Component.new(
        text: support_page_count_label(page_count),
        style: :default,
        size: :sm
      )
    end

    def support_published_badge
      render FlatPack::Badge::Component.new(text: "Published", style: :success, size: :sm)
    end

    def support_page_status_badge(recording)
      if recording.respond_to?(:current_publishable) && recording.current_publishable
        render RecordingStudioPublishable::StatusBadge::Component.new(
          publishable: recording.current_publishable
        )
      else
        render FlatPack::Badge::Component.new(text: "Draft", style: :info, size: :sm)
      end
    end

    def support_section_options(section_recordings)
      Array(section_recordings).filter_map do |recording|
        title = support_recording_title(recording)
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
