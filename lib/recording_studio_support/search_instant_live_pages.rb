# frozen_string_literal: true

module RecordingStudioSupport
  # Search Instant#show already passes actor and root into hits, then renders.
  # Keep that computation. Filter drafts on the way into render, before the
  # template reads @hits. Other models stay.
  module SearchInstantLivePages
    def show
      @_filter_instant_hits = true
      super
    ensure
      @_filter_instant_hits = false
    end

    def render(...)
      if @_filter_instant_hits
        @_filter_instant_hits = false
        @hits = InstantPages.live_only(@hits)
      end
      super
    end
  end
end
