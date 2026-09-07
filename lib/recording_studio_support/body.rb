# frozen_string_literal: true

module RecordingStudioSupport
  module Body
    module_function

    TAGS = %w[p br hr h1 h2 h3 h4 h5 h6 strong em u s ul ol li blockquote pre code a span img].freeze
    ATTRIBUTES = %w[href rel target src alt].freeze
    META_DESCRIPTION_LENGTH = 160

    def sanitize(html)
      html_sanitizer.sanitize(html.to_s, tags: TAGS, attributes: ATTRIBUTES).to_s
    end

    def plain_text(html)
      fragment = loofah_fragment(html.to_s)
      fragment.scrub!(:prune)
      text = fragment.text(encode_special_chars: false)
      text.to_s.gsub(/\s+/, " ").strip
    end

    def meta_description(html)
      text = plain_text(html)
      return if text.blank?

      return text if text.length <= META_DESCRIPTION_LENGTH

      text.truncate(META_DESCRIPTION_LENGTH)
    end

    def html_sanitizer
      @html_sanitizer ||= begin
        require "rails-html-sanitizer" unless defined?(Rails::HTML::SafeListSanitizer)
        Rails::HTML::SafeListSanitizer.new
      end
    end

    def loofah_fragment(html)
      require "loofah" unless defined?(Loofah)
      Loofah.html5_fragment(html)
    rescue ArgumentError, NameError
      Loofah.fragment(html)
    end
  end
end
