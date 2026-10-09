# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  def test_metrics_register_with_operations_expose_and_staff_view
    metrics = File.read(File.expand_path("../lib/recording_studio_support/metrics.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_support/engine.rb", __dir__))
    prepares = File.read(File.expand_path("../lib/recording_studio_support/engine/runtime_prepares.rb", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))
    dummy_metrics = File.read(File.expand_path("dummy/config/initializers/recording_studio_metrics.rb", __dir__))

    assert_includes metrics, "RecordingStudioMetrics.register"
    assert_includes metrics, ":support_tickets"
    assert_includes metrics, "RecordingStudioSupport::SupportTicket"
    assert_includes metrics, "count :open"
    assert_includes metrics, 'relation.where(status: "open")'
    assert_includes metrics, "breakdown :by_status"
    assert_includes metrics, "field: :status"
    assert_includes metrics, "breakdown :by_priority"
    assert_includes metrics, "field: :priority"
    assert_includes metrics, "timeseries :opened"
    assert_includes metrics, "field: :created_at"
    assert_includes metrics, ":support_pages"
    assert_includes metrics, "count :total"
    assert_includes metrics, "Admin::Queries.kept_page_recordings"
    assert_includes metrics, "blast_radius: :site"
    assert_includes metrics, "expose: EXPOSE"
    assert_includes metrics, "api: [API]"
    assert_includes metrics, "API = :operations"
    assert_includes metrics, "Api::Access.can_view_metrics?"
    refute_includes metrics, "confirmable_column?"
    refute_includes metrics, "RecordingStudioMetrics::Api.register!"
    refute_includes metrics, "respond_to?"
    refute_includes metrics, "rescue"

    assert_includes prepares, "RecordingStudioSupport::Metrics.register!"
    refute_includes engine, "RecordingStudioMetrics::Api.register!"
    refute_includes prepares, "RecordingStudioMetrics::Api.register!"

    assert_includes gemspec, 'spec.add_dependency "recording_studio_metrics", "~> 0.2"'
    assert_includes dummy_metrics, "RecordingStudioMetrics::Api.register!(api: :operations)"
  end
end
