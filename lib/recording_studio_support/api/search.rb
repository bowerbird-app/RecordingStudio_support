# frozen_string_literal: true

require_relative "search/context"
require_relative "search/token"
require_relative "search/paging"

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
        @payload ||= Paging.new(context: context, sort: group_sort, order: group_order).call(matched_recordings)
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
        relation = apply_live_only(apply_workspace_scope(kept(PAGE_TYPE)))
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
        return [recording.created_at, recording.id] if sort == "created_at"

        [recording.recordable.title.to_s.downcase, recording.id]
      end

      def collection_meta(meta)
        term = search_term
        return meta if term.blank?

        meta.merge(q: term)
      end

      def group_sort
        value = param(:sort).to_s
        return if value.blank? || value == "kind"
        return unless GROUP_SORTS.include?(value)

        value
      end

      def group_order
        param(:order).to_s.downcase == "desc" ? :desc : :asc
      end

      def search_term
        param(:q).to_s
      end

      def param(key)
        params = context.params
        return unless params.respond_to?(:[])

        params[key].presence || params[key.to_s].presence
      end
    end
  end
end
