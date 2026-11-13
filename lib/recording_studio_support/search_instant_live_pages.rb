# frozen_string_literal: true

module RecordingStudioSupport
  # Search 0.10 Instant hits are empty without an actor. Pass the controller
  # actor, then drop drafts so an allowlisted SupportPage cannot leak them.
  module SearchInstantLivePages
    def show
      @query = search_query
      @hits = instant_hits
      @hits = InstantPages.live_only(@hits)
      render layout: false
    end

    private

    def instant_hits
      hits = RecordingStudioSearch::InstantSearch.method(:hits_for)
      if hits.parameters.any? { |_kind, name| name == :actor }
        return RecordingStudioSearch::InstantSearch.hits_for(
          requested_models,
          @query,
          actor: search_actor,
          limit: 20
        )
      end

      RecordingStudioSearch::InstantSearch.hits_for(requested_models, @query, limit: 20)
    end
  end
end
