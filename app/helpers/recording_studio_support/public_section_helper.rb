# frozen_string_literal: true

module RecordingStudioSupport
  module PublicSectionHelper
    # PageNav for public section show: history back stays default; Home is the
    # secondary anchor to /help. Core recording_studio_page_nav does not yet
    # forward secondary_anchor_* — hosts wire those via content_for (see dummy
    # default_layout).
    def support_public_section_page_nav(title:)
      recording_studio_page_nav(
        title: title,
        page_nav_back_url: support_public_help_path
      )
      content_for(:page_nav_secondary_anchor_url, support_public_help_path)
      content_for(:page_nav_secondary_anchor_icon, "home")
      content_for(:page_nav_secondary_anchor_tooltip, "Home")
      nil
    end

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
