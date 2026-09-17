# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Index
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        authorize_index!
        blocked = search_block
        return blocked if blocked

        collection_response(paginated_recordings)
      end

      private

      attr_reader :context

      def authorize_index!
        return if Access.can_view_as_staff?(context)

        workspace = context.access_grant.scope_recording
        return if Access.can_view_workspace?(context, workspace)

        Access.deny!
      end

      def search_block
        return unless context.recordable_type == Api::PAGE_TYPE

        SearchLimit.blocked_response(client_id: context.api_client&.id, query: search_term)
      end

      def collection_response(payload)
        {
          json: Serialize.collection(
            payload.fetch(:rows),
            context: context,
            meta: collection_meta(payload.fetch(:meta))
          )
        }
      end

      def collection_meta(meta)
        term = search_term
        return meta if term.blank?

        meta.merge(q: term)
      end

      def paginated_recordings
        pagination = RecordingStudioApi::Services::PaginateResourceCollection.call(**pagination_args)
        raise RecordingStudioApi::InvalidPaginationTokenError, pagination.error if pagination.failure?

        pagination.value
      end

      def pagination_args
        {
          relation: filtered_recordings,
          resource: context.resource_name,
          recordable_type: context.recordable_type,
          api: context.api_key,
          scope_key: "client:#{context.api_client.id}"
        }.merge(query_params)
      end

      def query_params
        params = context.params
        {
          limit: params[:limit],
          pagination_token: params[:pagination_token],
          sort: params[:sort],
          order: params[:order]
        }
      end

      def filtered_recordings
        relation = apply_workspace_scope(kept_recordings)
        relation = apply_live_only(relation)
        apply_search(relation)
      end

      def kept_recordings
        RecordingStudio::Recording.where(
          recordable_type: context.recordable_type,
          trashed_at: nil
        )
      end

      def apply_workspace_scope(relation)
        return relation if Access.can_view_as_staff?(context)

        workspace = context.access_grant.scope_recording
        relation.where(root_recording_id: workspace.id)
      end

      def apply_live_only(relation)
        return relation if Access.can_view_as_staff?(context)
        return relation unless context.recordable_type == Api::PAGE_TYPE

        relation.where(recordable_id: SupportPage.indexable.select(:id))
      end

      def apply_search(relation)
        return relation unless context.recordable_type == Api::PAGE_TYPE

        Pages.apply_query(relation, search_term)
      end

      def search_term
        params = context.params
        return "" unless params.respond_to?(:[])

        (params[:q].presence || params["q"].presence).to_s
      end
    end
  end
end
