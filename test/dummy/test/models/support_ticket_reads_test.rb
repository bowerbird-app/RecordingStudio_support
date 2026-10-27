# frozen_string_literal: true

require "test_helper"

class SupportTicketReadsTest < ActiveSupport::TestCase
  TICKET_METRICS = %w[
    support_tickets.open
    support_tickets.unassigned_open
    support_tickets.oldest_open_age
    support_tickets.by_status
    support_tickets.by_priority
    support_tickets.opened
    support_tickets.avg_time_to_resolve
  ].freeze

  setup do
    @patron = RecordingStudioUser.create_user!(
      email: "ticket-reads-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @staff = RecordingStudioUser.create_user!(
      email: "ticket-reads-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Staff",
      time_zone: "UTC"
    )
    Current.actor = @staff
    RecordingStudioSupport::SupportTicket.delete_all
  end

  teardown do
    Current.actor = nil
  end

  test "a ticket revised three times counts once and keeps the recording open time" do
    opened_at = Time.utc(2026, 3, 1, 12)
    ticket = travel_to(opened_at) do
      RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "Revised queue #{SecureRandom.hex(4)}",
        body: "Still open.",
        priority: :normal
      )
    end
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)

    travel_to(opened_at + 1.hour) do
      recording = RecordingStudioSupport::Tickets.update!(recording, actor: @staff, priority: :high)
    end
    travel_to(opened_at + 2.hours) do
      recording = RecordingStudioSupport::Tickets.update!(recording, actor: @staff, assignee: @staff)
    end
    travel_to(opened_at + 3.hours) do
      recording = RecordingStudioSupport::Tickets.update!(recording, actor: @staff, priority: :low)
    end

    assert_equal 4, RecordingStudioSupport::SupportTicket.where(subject: ticket.subject).count
    assert_equal 1, RecordingStudioSupport::Tickets.current.where(subject: ticket.subject).count

    travel_to(opened_at + 5.hours) do
      assert_equal 1, metric_value("support_tickets.open")
      assert_equal 0, metric_value("support_tickets.unassigned_open")
      assert_in_delta 5.hours.to_i, metric_value("support_tickets.oldest_open_age"), 2
      assert_equal 1, breakdown_value("support_tickets.by_status", "open")
      assert_equal 1, breakdown_value("support_tickets.by_priority", "low")
      assert_equal 1, series_value("support_tickets.opened", "2026-03-01")
      assert_equal 1, RecordingStudioSupport::Admin::OpenTicketsScreen.tickets.count
      assert_equal 0, RecordingStudioSupport::Admin::TimeToCloseScreen.tickets.count
      assert_equal 0, RecordingStudioSupport::Admin::Widgets::UNASSIGNED_OPEN.resolve(metric_context).value
      assert_equal "5h", RecordingStudioSupport::Admin::Widgets::OLDEST_OPEN_AGE.resolve(metric_context).value
    end

    travel_to(opened_at + 4.hours) do
      RecordingStudioSupport::Tickets.update!(recording, actor: @staff, status: :resolved)
    end

    assert_operator RecordingStudioSupport::SupportTicket.where(status: "open").count, :>=, 1
    assert_equal 0, RecordingStudioSupport::Tickets.current.where(status: "open").count
    assert_equal 1, RecordingStudioSupport::Admin::TimeToCloseScreen.tickets.count
    assert_equal 0, RecordingStudioSupport::Admin::OpenTicketsScreen.tickets.count

    closed = RecordingStudioSupport::Admin::TimeToCloseScreen.tickets.first
    assert_in_delta 4.hours.to_i, closed.resolved_at - RecordingStudioSupport::Admin::OpenTicketsScreen.opened_at(closed), 2

    travel_to(opened_at + 6.hours) do
      assert_nil metric_value("support_tickets.oldest_open_age")
      assert_in_delta 4.hours.to_i, series_value("support_tickets.avg_time_to_resolve", "2026-03-01"), 2
      assert_equal 1, series_value("support_tickets.opened", "2026-03-01")
      assert_equal 240, close_chart_value
    end

    TICKET_METRICS.each do |identifier|
      assert RecordingStudioMetrics.registry.fetch(identifier)
      assert_equal identifier, RecordingStudioMetrics.registry.fetch(identifier).identifier
    end
  end

  private

  def metric_context
    @metric_context ||= Struct.new(:actor, :blast_radius, :timezone).new(@staff, :site, "UTC")
  end

  def metric_value(identifier)
    RecordingStudioSupport::Admin::Widgets.metric_value(identifier, metric_context)
  end

  def breakdown_value(identifier, key)
    result = execute(identifier)
    row = Array(result.data).find { |entry| entry[:key].to_s == key || entry["key"].to_s == key }
    row ? (row[:value] || row["value"]).to_i : 0
  end

  def close_chart_value
    rows = RecordingStudioSupport::Admin::DurationAxis.series(
      "support_tickets.avg_time_to_resolve",
      metric_context,
      interval: "month",
      start_at: Time.utc(2026, 3, 1),
      end_at: Time.utc(2026, 4, 1),
      cache: false
    )
    point = rows.flat_map { |row| row[:data] || row["data"] }.find do |entry|
      (entry[:x] || entry["x"]).to_s == "2026-03-01"
    end
    (point[:y] || point["y"]).to_f
  end

  def series_value(identifier, date)
    result = execute(identifier, interval: "month", start_at: Time.utc(2026, 3, 1), end_at: Time.utc(2026, 4, 1))
    row = Array(result.data).find { |entry| (entry[:date] || entry["date"]).to_s == date }
    row ? (row[:value] || row["value"]).to_f : 0
  end

  def execute(identifier, **params)
    RecordingStudioMetrics::Admin.execute(
      identifier,
      admin_context: metric_context,
      site_authorized: true,
      scope: :site,
      cache: false,
      **params
    )
  end
end
