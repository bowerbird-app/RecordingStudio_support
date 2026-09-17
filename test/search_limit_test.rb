# frozen_string_literal: true

require "test_helper"
require "securerandom"

class SearchLimitTest < Minitest::Test
  def setup
    @original = {
      enabled: RecordingStudioSupport.configuration.api_search_rate_limit_enabled,
      requests: RecordingStudioSupport.configuration.api_search_rate_limit_requests,
      period: RecordingStudioSupport.configuration.api_search_rate_limit_period_seconds
    }
    RecordingStudioSupport.configuration.api_search_rate_limit_enabled = true
    RecordingStudioSupport.configuration.api_search_rate_limit_requests = 2
    RecordingStudioSupport.configuration.api_search_rate_limit_period_seconds = 60
    RecordingStudioSupport::Api::SearchLimit.reset!
  end

  def teardown
    RecordingStudioSupport.configuration.api_search_rate_limit_enabled = @original[:enabled]
    RecordingStudioSupport.configuration.api_search_rate_limit_requests = @original[:requests]
    RecordingStudioSupport.configuration.api_search_rate_limit_period_seconds = @original[:period]
    RecordingStudioSupport::Api::SearchLimit.reset!
  end

  def test_blank_query_is_not_limited
    3.times do
      assert_nil RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: "c1", query: " ")
    end
  end

  def test_blocks_after_the_configured_window
    client = "c-#{SecureRandom.hex(4)}"
    assert_nil RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: client, query: "invoice")
    assert_nil RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: client, query: "invoice")

    blocked = RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: client, query: "invoice")
    assert blocked
    assert_equal :too_many_requests, blocked.fetch(:status)
    assert_equal "rate_limit_exceeded", blocked.dig(:json, :error, :code)
    assert_equal "60", blocked.fetch(:headers).fetch("Retry-After")
  end

  def test_disabled_limit_never_blocks
    RecordingStudioSupport.configuration.api_search_rate_limit_enabled = false
    client = "c-#{SecureRandom.hex(4)}"

    5.times do
      assert_nil RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: client, query: "invoice")
    end
  end

  def test_separate_clients_have_separate_buckets
    first = "a-#{SecureRandom.hex(4)}"
    second = "b-#{SecureRandom.hex(4)}"
    2.times { RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: first, query: "card") }

    assert_nil RecordingStudioSupport::Api::SearchLimit.blocked_response(client_id: second, query: "card")
  end
end
