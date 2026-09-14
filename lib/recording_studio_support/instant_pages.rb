# frozen_string_literal: true

module RecordingStudioSupport
  # Instant UI for help articles. Query still goes through Search Instant
  # (`SupportPage.search` / trigram). Results stay scoped to the section and
  # to live pages on the public engine endpoint.
  module InstantPages
    MODEL_NAME = "RecordingStudioSupport::SupportPage"
    FRAME_ID = "support_page_search_results"

    module_function

    def hits(query:, section_recording:, audience:)
      scope = page_scope(section_recording, audience)
      term = query.to_s.strip
      return scope if term.blank?

      matched = RecordingStudioSearch::InstantSearch.hits_for([MODEL_NAME], term, limit: 20)
      relation = search_relation(matched)
      return scope.none if relation.blank?

      scope.where(id: relation.unscope(:order).reselect(:id)).limit(20)
    end

    def public_articles(section_recording, query:)
      hits(query: query, section_recording: section_recording, audience: :public).filter_map do |page|
        PublicSection.article_for(page)
      end
    end

    def staff_recordings(section_recording, query:)
      matched = hits(query: query, section_recording: section_recording, audience: :staff)
      page_ids = matched.unscope(:order).reselect(:id)
      Pages.kept_pages_for_section(section_recording)
           .where(recordable_id: page_ids)
           .reorder(:recording_studio_orderable_position, :created_at, :id)
           .preload(:recordable)
    end

    def live_only(hits)
      case hits
      when ActiveRecord::Relation
        return hits unless hits.klass == SupportPage

        hits.where(id: SupportPage.indexable.select(:id))
      when Hash
        hits.transform_values { |relation| live_only(relation) }
      else
        hits
      end
    end

    def page_scope(section_recording, audience)
      if audience.to_sym == :public
        Pages.public_for_section(section_recording)
      else
        page_ids = Pages.kept_pages_for_section(section_recording).select(:recordable_id)
        SupportPage.where(id: page_ids)
      end
    end
    private_class_method :page_scope

    def search_relation(matched)
      return matched if matched.is_a?(ActiveRecord::Relation)
      return if matched.blank?

      matched[SupportPage] || matched[MODEL_NAME]
    end
    private_class_method :search_relation
  end
end
