# frozen_string_literal: true

require "test_helper"

class SupportPageViewsMetricsTest < ActiveSupport::TestCase
  setup do
    @actor = User.create!(
      email: "page-views-metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    RecordingStudioMetrics.registry.reset!
    RecordingStudioSupport::Metrics.register!
  end

  teardown do
    RecordingStudioMetrics.registry.reset!
    RecordingStudioSupport::Metrics.register!
    RecordingStudioUser::Metrics.register! if defined?(RecordingStudioUser::Metrics)
  end

  test "over_time catalog_metadata carries Metrics 0.3 date range and freshness" do
    definition = RecordingStudioMetrics.find("support_page_views.over_time")

    assert_equal :timeseries, definition.result_type
    assert_equal "views", definition.unit
    assert_equal :created_at, definition.field
    assert_equal [], definition.group_by
    assert_equal :site, definition.blast_radius
    assert definition.exposed_to_api?(:operations)

    catalog = definition.catalog_metadata
    assert_equal "support_page_views.over_time", catalog[:identifier]
    assert_equal "views", catalog[:unit]
    assert_equal [], catalog[:group_by]
    assert catalog.dig(:date_range, :supported)
    assert catalog.key?(:timezone)
    assert catalog.key?(:freshness)
    refute catalog.key?(:min_group_size)
  end

  test "execute handler returns the series when access allows" do
    grant_view!(@actor, @admin_recording)
    recording_id = SecureRandom.uuid
    travel_to(Time.utc(2025, 3, 5, 9)) do
      record_help_view!(recording_id: recording_id, at: Time.utc(2025, 3, 5, 9))
    end

    payload = RecordingStudioMetrics::Api::ExecuteHandler.call(
      build_api_context(@actor, resource: "support_page_views", name: "over_time")
    )

    assert_equal "support_page_views.over_time", payload[:metric]
    assert_equal "views", payload[:unit]
    values = payload.fetch(:data).to_h { |row| [row[:date].to_s, row[:value]] }
    assert_equal 1, values.fetch("2025-03-05")
  end

  test "execute handler is 403 when access denies" do
    error = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        build_api_context(@actor, resource: "support_page_views", name: "over_time")
      )
    end

    assert_match(/not authorized/i, error.message)
  end

  test "discovery hides the metric from denied callers and shows it to AdminRoot viewers" do
    denied = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    refute_includes denied.fetch(:metrics).map { |row| row[:identifier] }, "support_page_views.over_time"

    grant_view!(@actor, @admin_recording)
    allowed = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    row = allowed.fetch(:metrics).find { |metric| metric[:identifier] == "support_page_views.over_time" }

    assert row
    assert_equal "views", row[:unit]
    assert_equal [], row[:group_by]
    assert row.dig(:date_range, :supported)
    assert row.key?(:timezone)
    assert row.key?(:freshness)
  end

  private

  def build_api_context(actor, resource: nil, name: nil)
    grant = Struct.new(:actor).new(actor)
    params = {
      resource: resource,
      name: name,
      interval: "day",
      start: "2025-03-05T00:00:00Z",
      start_at: nil,
      end: "2025-03-06T00:00:00Z",
      end_at: nil,
      timezone: "UTC",
      filters: {}
    }
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:api_client) { actor }
    context.define_singleton_method(:access_recording) { nil }
    context.define_singleton_method(:root_recording) { nil }
    context.define_singleton_method(:api_key) { :operations }
    context.define_singleton_method(:params) { params }
    context
  end

  def grant_view!(actor, recording)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: actor
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
