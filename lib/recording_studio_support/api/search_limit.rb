# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class SearchLimit
      HEADERS = {
        retry_after: "Retry-After",
        limit: "X-RateLimit-Limit",
        remaining: "X-RateLimit-Remaining"
      }.freeze

      class MemoryStore
        def initialize
          @mutex = Mutex.new
          @counts = Hash.new(0)
        end

        def increment(key)
          @mutex.synchronize { @counts[key] += 1 }
        end

        def reset!
          @mutex.synchronize { @counts.clear }
        end
      end

      STORE = MemoryStore.new

      def self.reset!
        STORE.reset!
      end

      def self.blocked_response(client_id:, query:)
        new(client_id: client_id, query: query).blocked_response
      end

      def initialize(client_id:, query:)
        @client_id = client_id
        @query = query.to_s.strip
      end

      def blocked_response
        return if @query.blank? || !enabled? || @client_id.blank?

        count = increment
        return unless count > limit

        {
          json: {
            error: {
              code: "rate_limit_exceeded",
              message: "Too many article searches"
            }
          },
          status: :too_many_requests,
          headers: {
            HEADERS[:retry_after] => period.to_s,
            HEADERS[:limit] => limit.to_s,
            HEADERS[:remaining] => "0"
          }
        }
      end

      private

      def enabled?
        RecordingStudioSupport.configuration.api_search_rate_limit_enabled
      end

      def limit
        RecordingStudioSupport.configuration.api_search_rate_limit_requests.to_i
      end

      def period
        RecordingStudioSupport.configuration.api_search_rate_limit_period_seconds.to_i
      end

      def increment
        return 0 if limit <= 0 || period <= 0

        STORE.increment(memory_key)
      end

      def memory_key
        window = Time.now.to_i / period
        "support-search:#{@client_id}:#{window}"
      end
    end
  end
end
