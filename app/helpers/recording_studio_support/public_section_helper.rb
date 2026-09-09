# frozen_string_literal: true

module RecordingStudioSupport
  module PublicSectionHelper
    def support_page_snippet(body)
      Body.snippet(body)
    end

    def support_public_section_subtitle(section)
      PublicSection.subtitle_for(section)
    end

    def support_public_section_search_placeholder(section)
      "Search in #{section.title}…"
    end

    def support_public_contact_href
      RecordingStudioSupport.configuration.public_contact_href.presence
    end

    def support_public_contact_label
      RecordingStudioSupport.configuration.public_contact_label.presence || "Contact support"
    end

    def support_public_contact_prompt(section)
      "Need something else in #{section.title}?"
    end

    def support_public_section_article(page)
      PublicSection.article_for(page)
    end
  end
end
