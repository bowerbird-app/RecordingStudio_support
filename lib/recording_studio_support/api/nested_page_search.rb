# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module NestedPageSearch
      def index
        blocked = page_search_block
        return render_search_limit(blocked) if blocked

        super
      end

      def scoped_children(include_trashed: false)
        apply_page_search(super)
      end

      private

      def page_search_block
        return unless support_pages_collection?

        SearchLimit.blocked_response(
          client_id: current_api_client&.id,
          query: search_query_term
        )
      end

      def support_pages_collection?
        support_section_parent? && relationship.child_type == RecordingStudioSupport::Api::PAGE_TYPE
      rescue RecordingStudioApi::NotFoundError, RecordingStudioApi::UnsupportedActionError
        false
      end

      def apply_page_search(relation)
        return relation unless support_pages_collection?

        Pages.apply_query(relation, search_query_term)
      end

      def search_query_term
        params[:q].presence || params["q"].presence || ""
      end

      def render_search_limit(blocked)
        blocked.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
        render json: blocked.fetch(:json), status: blocked.fetch(:status)
      end
    end
  end
end
