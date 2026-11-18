# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Search
      NAME = :search_support_pages
      PATH = "support_page_search"
      TITLE = "Search support pages"
      RESOURCE = "support_pages"
      QUERY = "Text matched against the published page title and body."

      def self.register!
        return unless defined?(RecordingStudioApi)
        return if RecordingStudioApi.registered_endpoint(NAME, api: :public)

        RecordingStudioApi.register_endpoint(
          NAME, api: :public, http_verb: :get, path: PATH, handler: self,
                openapi: openapi, input_contract: input_contract
        )
      end

      def self.openapi
        {
          title: TITLE, summary: TITLE, description: "Search published support pages by title and body.",
          tags: ["Support Page"], tag: { group: "Support" },
          parameters: [{ name: "q", in: "query", required: false, description: QUERY, schema: { type: "string" } }]
        }
      end

      def self.input_contract
        { reject_unknown: false, fields: { q: { type: :string, required: false, description: QUERY } } }
      end

      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        authorize!
        collection(paginated)
      end

      private

      attr_reader :context

      def authorize!
        return if Access.can_view_as_support_team?(context)

        workspace = context.access_grant.scope_recording
        return if Access.can_view_workspace?(context, workspace)

        Access.deny!
      end

      def paginated
        pagination = RecordingStudioApi::Services::PaginateResourceCollection.call(**pagination_args)
        raise RecordingStudioApi::InvalidPaginationTokenError, pagination.error if pagination.failure?

        pagination.value
      end

      def pagination_args
        {
          relation: published_recordings, resource: RESOURCE, recordable_type: PAGE_TYPE,
          api: context.api_key, scope_key: "client:#{context.api_client.id}",
          limit: params[:limit], pagination_token: params[:pagination_token], sort: params[:sort], order: params[:order]
        }
      end

      def published_recordings
        Pages.for_root(SupportCenters.current, query: search_term).where(
          recordable_id: SupportPage.indexable.select(:id)
        )
      end

      def collection(page)
        {
          resource: RESOURCE, type: "SupportPage",
          records: page.rows.map { |recording| Serialize.recording(recording, context: context) },
          meta: collection_meta(page.meta)
        }
      end

      def collection_meta(meta)
        return meta if search_term.blank?

        meta.merge(q: search_term)
      end

      def search_term
        (params[:q].presence || params["q"].presence).to_s
      end

      def params
        context.params
      end
    end
  end
end
