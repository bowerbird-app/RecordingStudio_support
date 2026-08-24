# frozen_string_literal: true

module RecordingStudioSupport
  module Body
    module_function

    TAGS = %w[p br hr h1 h2 h3 h4 h5 h6 strong em u s ul ol li blockquote pre code a span].freeze
    ATTRIBUTES = %w[href rel target].freeze

    def sanitize(html)
      html_sanitizer.sanitize(html.to_s, tags: TAGS, attributes: ATTRIBUTES).to_s
    end

    def html_sanitizer
      @html_sanitizer ||= begin
        require "rails-html-sanitizer" unless defined?(Rails::HTML::SafeListSanitizer)
        Rails::HTML::SafeListSanitizer.new
      end
    end
  end
end
