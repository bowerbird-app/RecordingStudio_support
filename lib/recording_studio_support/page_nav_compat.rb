# frozen_string_literal: true

module RecordingStudioSupport
  # Recording Studio 4.2's default layout passes `anchor_url` / `back_url`.
  # Flatpack 0.1.133+ PageNav reads `anchor_href` / `secondary_anchor_href` and
  # always uses history.back for back unless Flatpack is given a back override.
  module PageNavCompat
    def initialize(**kwargs)
      map_url_to_href!(kwargs, :anchor_url, :anchor_href)
      map_url_to_href!(kwargs, :secondary_anchor_url, :secondary_anchor_href)
      kwargs.delete(:back_url)
      # Mutated kwargs must be passed through. Bare `super` would send the original keywords.
      super(**kwargs) # rubocop:disable Style/SuperArguments
    end

    private

    def map_url_to_href!(kwargs, url_key, href_key)
      return unless kwargs.key?(url_key)

      kwargs[href_key] = kwargs[href_key].presence || kwargs.delete(url_key)
      kwargs.delete(url_key)
    end
  end
end
