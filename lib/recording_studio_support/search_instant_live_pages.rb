# frozen_string_literal: true

module RecordingStudioSupport
  # Search InstantSearchesController has no auth. Help drafts must not leak
  # when SupportPage is allowlisted.
  module SearchInstantLivePages
    def show
      @query = search_query
      @hits = RecordingStudioSearch::InstantSearch.hits_for(requested_models, @query, limit: 20)
      @hits = InstantPages.live_only(@hits)
      render layout: false
    end
  end
end
