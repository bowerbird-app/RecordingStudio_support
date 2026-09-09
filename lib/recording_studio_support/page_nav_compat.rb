# frozen_string_literal: true

module RecordingStudioSupport
  # Recording Studio 4.2's default layout passes `anchor_url` / `back_url`.
  # Flatpack 0.1.133+ PageNav reads `anchor_href` / `secondary_anchor_href` and
  # always uses history.back for back unless Flatpack is given a back override.
  module PageNavCompat
    def initialize(**kwargs)
      if kwargs.key?(:anchor_url)
        kwargs[:anchor_href] = kwargs[:anchor_href].presence || kwargs.delete(:anchor_url)
        kwargs.delete(:anchor_url)
      end
      if kwargs.key?(:secondary_anchor_url)
        kwargs[:secondary_anchor_href] =
          kwargs[:secondary_anchor_href].presence || kwargs.delete(:secondary_anchor_url)
        kwargs.delete(:secondary_anchor_url)
      end
      kwargs.delete(:back_url)
      # Mutated kwargs must be passed through. Bare `super` would send the original keywords.
      super(**kwargs) # rubocop:disable Style/SuperArguments
    end
  end
end
