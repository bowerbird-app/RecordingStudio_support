# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Search
      class Paging
        def initialize(context:, sort:, order:)
          @context = context
          @sort = sort
          @order = order
        end

        def call(rows)
          limit = normalize_limit
          offset = Token.offset(context.params)
          page = Array(rows[offset, limit])
          has_more = rows.length > offset + limit

          {
            rows: page,
            meta: page_meta(limit: limit, offset: offset, has_more: has_more)
          }
        end

        private

        attr_reader :context, :sort, :order

        def page_meta(limit:, offset:, has_more:)
          {
            limit: limit,
            sort: sort.presence || "kind",
            order: sort.present? ? order.to_s : "asc",
            has_more: has_more,
            next_pagination_token: (Token.encode(offset + limit) if has_more)
          }
        end

        def normalize_limit
          requested = context.params[:limit].to_i
          requested = default_limit if requested <= 0
          [requested, max_limit].min
        end

        def default_limit
          configured_limit(:pagination_default_limit, DEFAULT_LIMIT)
        end

        def max_limit
          configured_limit(:pagination_max_limit, MAX_LIMIT)
        end

        def configured_limit(name, fallback)
          return fallback unless defined?(RecordingStudioApi)

          value = RecordingStudioApi.configuration.public_send(name).to_i
          value.positive? ? value : fallback
        rescue StandardError
          fallback
        end
      end
    end
  end
end
