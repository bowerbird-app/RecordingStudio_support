# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Search
      RESOURCE_NAME = "support_search"
      TOKEN_PURPOSE = "recording_studio_support.support_search"
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 100
      GROUP_SORTS = %w[title created_at].freeze

      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = Context.new(context)
      end

      def call
        authorize!
        blocked = SearchLimit.blocked_response(client_id: context.api_client&.id, query: search_term)
        return blocked if blocked

        {
          json: Serialize.search_collection(
            payload.fetch(:rows),
            context: context,
            meta: collection_meta(payload.fetch(:meta))
          )
        }
      end

      private

      attr_reader :context

      def payload
        @payload ||= paginate(matched_recordings)
      end

      def authorize!
        return if Access.can_view_as_staff?(context)

        workspace = context.access_grant.scope_recording
        return if Access.can_view_workspace?(context, workspace)

        Access.deny!
      end

      def matched_recordings
        sort_group(scoped_sections.to_a) + sort_group(scoped_pages.to_a)
      end

      def scoped_sections
        Sections.apply_query(apply_workspace_scope(kept(SECTION_TYPE)), search_term).preload(:recordable)
      end

      def scoped_pages
        relation = apply_workspace_scope(kept(PAGE_TYPE))
        relation = apply_live_only(relation)
        Pages.apply_query(relation, search_term).preload(:recordable)
      end

      def kept(type)
        RecordingStudio::Recording.where(recordable_type: type, trashed_at: nil)
      end

      def apply_workspace_scope(relation)
        return relation if Access.can_view_as_staff?(context)

        relation.where(root_recording_id: context.access_grant.scope_recording.id)
      end

      def apply_live_only(relation)
        return relation if Access.can_view_as_staff?(context)

        relation.where(recordable_id: SupportPage.indexable.select(:id))
      end

      def sort_group(rows)
        sort = group_sort
        return rows if sort.blank?

        ordered = rows.sort_by { |recording| group_sort_key(recording, sort) }
        group_order == :desc ? ordered.reverse : ordered
      end

      def group_sort_key(recording, sort)
        if sort == "created_at"
          [recording.created_at, recording.id]
        else
          [recording.recordable.title.to_s.downcase, recording.id]
        end
      end

      def paginate(rows)
        limit = normalize_limit
        offset = token_offset
        page = Array(rows[offset, limit])
        has_more = rows.length > offset + limit

        {
          rows: page,
          meta: {
            limit: limit,
            sort: group_sort.presence || "kind",
            order: group_sort.present? ? group_order.to_s : "asc",
            has_more: has_more,
            next_pagination_token: (encode_offset(offset + limit) if has_more)
          }
        }
      end

      def collection_meta(meta)
        term = search_term
        return meta if term.blank?

        meta.merge(q: term)
      end

      def normalize_limit
        requested = context.params[:limit].to_i
        requested = pagination_default_limit if requested <= 0
        [requested, pagination_max_limit].min
      end

      def pagination_default_limit
        configured_limit(:pagination_default_limit, DEFAULT_LIMIT)
      end

      def pagination_max_limit
        configured_limit(:pagination_max_limit, MAX_LIMIT)
      end

      def configured_limit(name, fallback)
        return fallback unless defined?(RecordingStudioApi)

        value = RecordingStudioApi.configuration.public_send(name).to_i
        value.positive? ? value : fallback
      rescue StandardError
        fallback
      end

      def token_offset
        token = context.params[:pagination_token].presence || context.params["pagination_token"].presence
        return 0 if token.blank?

        payload = token_verifier.verify(token.to_s, purpose: TOKEN_PURPOSE)
        raise invalid_token unless payload.is_a?(Hash)

        offset = payload.fetch("o")
        raise invalid_token unless offset.is_a?(Integer) && offset >= 0

        offset
      rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, TypeError
        raise invalid_token
      end

      def encode_offset(offset)
        token_verifier.generate({ "o" => offset }, purpose: TOKEN_PURPOSE)
      end

      def token_verifier
        Rails.application.message_verifier(TOKEN_PURPOSE)
      end

      def invalid_token
        RecordingStudioApi::InvalidPaginationTokenError.new("Invalid pagination token")
      end

      def group_sort
        value = (context.params[:sort].presence || context.params["sort"].presence).to_s
        return if value.blank? || value == "kind"
        return unless GROUP_SORTS.include?(value)

        value
      end

      def group_order
        value = (context.params[:order].presence || context.params["order"].presence).to_s.downcase
        value == "desc" ? :desc : :asc
      end

      def search_term
        params = context.params
        return "" unless params.respond_to?(:[])

        (params[:q].presence || params["q"].presence).to_s
      end

      class Context
        def initialize(endpoint_context)
          @endpoint_context = endpoint_context
        end

        def resource_name
          RESOURCE_NAME
        end

        def api_version
          "v1"
        end

        def api_client
          @endpoint_context.api_client
        end

        def access_grant
          @endpoint_context.access_grant
        end

        def params
          @endpoint_context.params
        end

        def api_key
          @endpoint_context.api_key
        end
      end
    end
  end
end
