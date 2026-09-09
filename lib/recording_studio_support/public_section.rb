# frozen_string_literal: true

module RecordingStudioSupport
  module PublicSection
    module_function

    def subtitle_for(section)
      configured = RecordingStudioSupport.configuration.public_section_subtitle
      result = configured.respond_to?(:call) ? configured.call(section) : configured
      result.to_s.presence || "Find answers in #{section.title}."
    end

    def articles_for(section_recording, query: nil)
      Pages.public_for_section(section_recording, query: query).filter_map do |page|
        article_for(page)
      end
    end

    def article_for(page)
      href = page.published_url
      return if href.blank?

      {
        title: page.title,
        href: href,
        snippet: Body.snippet(page.body),
        updated_at: article_updated_at(page)
      }
    end

    def article_updated_at(page)
      recording = Pages.recording_for(page)
      publishable = recording&.current_publishable if recording.respond_to?(:current_publishable)
      publishable&.publish_at.presence || recording&.updated_at.presence || page.created_at
    end
  end
end
