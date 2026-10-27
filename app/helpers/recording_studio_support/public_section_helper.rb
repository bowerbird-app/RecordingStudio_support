# frozen_string_literal: true

module RecordingStudioSupport
  module PublicSectionHelper
    def support_public_section_page_nav(title:)
      support_page_chrome(
        title: title,
        back_href: support_public_help_path,
        back_tooltip: Copy.t("help.home")
      )
    end

    def support_page_snippet(body)
      Body.snippet(body)
    end

    def support_public_section_subtitle(section)
      PublicSection.subtitle_for(section)
    end

    def support_public_section_search_placeholder(section)
      Copy.t("section.search_placeholder", title: section.title)
    end

    def support_public_contact_href
      RecordingStudioSupport.configuration.public_contact_href.presence
    end

    def support_public_contact_label
      Copy.defaulted(
        RecordingStudioSupport.configuration.public_contact_label.presence,
        Configuration::DEFAULTS[:public_contact_label],
        "contact.label"
      )
    end

    def support_public_contact_prompt(section)
      Copy.t("contact.prompt", title: section.title)
    end

    # Section search EmptyState copy. Pass a Flatpack Link (or nil) so Contact
    # stays an inline link instead of a Button slot. The link must stay HTML —
    # I18n escapes a plain string even when the key ends in `_html`.
    def support_public_search_empty_description(contact_link: nil)
      return Copy.t("search.empty") if contact_link.blank?

      contact = contact_link.html_safe
      html = Copy.t("search.empty_with_contact_html", contact: contact)
      html.respond_to?(:html_safe) ? html.html_safe : html
    end

    def support_public_section_article(page)
      PublicSection.article_for(page)
    end
  end
end
