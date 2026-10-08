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
        collection_response(paginated_recordings)
      end

      private

      attr_reader :context

      def authorize_index!
        if Access.operations_api?(context)
          Access.authorize_staff_view!(context)
          return
        end

        return if Access.can_view_as_staff?(context)

        workspace = context.access_grant.scope_recording
        return if Access.can_view_workspace?(context, workspace)

        Access.deny!
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
        return section_recordings if context.recordable_type == Api::SECTION_TYPE
        return nested_page_recordings if nested_section_id.present?

        page_recordings
      end

      def nested_page_recordings
        Pages.for_section(Lookup.section!(id: nested_section_id), query: search_term)
      end

      def nested_section_id
        return context.parent_id if context.respond_to?(:parent_id) && context.parent_id.present?

        nil
      end

      def section_recordings
        Sections.public_index
      end

      def page_recordings
        workspace = context.access_grant.scope_recording
        relation = Pages.for_root(workspace, query: search_term)
        return relation if Access.can_view_as_staff?(context)

        relation.where(recordable_id: SupportPage.indexable.select(:id))
      end

      def search_term
        params = context.params
        return "" unless params.respond_to?(:[])

        (params[:q].presence || params["q"].presence).to_s
      end
    end
  end
end
