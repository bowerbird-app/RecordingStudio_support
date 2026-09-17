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
        payload = paginated_recordings
        {
          json: Serialize.collection(
            payload.fetch(:rows),
            context: context,
            meta: payload.fetch(:meta)
          )
        }
      end

      private

      attr_reader :context

      def authorize_index!
        return if Access.can_view_as_staff?(context)

        workspace = context.access_grant.scope_recording
        return if Access.can_view_workspace?(context, workspace)

        Access.deny!
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
        apply_live_only(relation)
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
    end
  end
end
