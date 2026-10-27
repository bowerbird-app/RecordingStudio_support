# frozen_string_literal: true

require "test_helper"

class SupportTicketEventsTest < ActiveSupport::TestCase
  setup do
    @patron = RecordingStudioUser.create_user!(
      email: "ticket-events-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @staff = RecordingStudioUser.create_user!(
      email: "ticket-events-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Staff",
      time_zone: "UTC"
    )
    Current.actor = @staff
  end

  teardown do
    Current.actor = nil
  end

  test "opening a ticket records a created event for the actor" do
    ticket = open_ticket!
    event = created_event(ticket)

    assert_equal "created", event.action
    assert_equal @patron, event.actor
    assert_nil event.previous_recordable
    assert_equal ticket, event.recordable
  end

  test "status priority and assignee changes record an updated event with the diff" do
    ticket = open_ticket!
    original = ticket

    status_recording = RecordingStudioSupport::Tickets.update!(ticket, actor: @staff, status: :resolved)
    status_event = latest_event(status_recording)
    assert_equal "updated", status_event.action
    assert_equal @staff, status_event.actor
    assert_equal original, status_event.previous_recordable
    assert_equal({ "status" => %w[open resolved] }, status_event.metadata["changes"])

    priority_recording = RecordingStudioSupport::Tickets.update!(
      status_recording, actor: @staff, priority: :high
    )
    priority_event = latest_event(priority_recording)
    assert_equal @staff, priority_event.actor
    assert_equal status_recording.recordable, priority_event.previous_recordable
    assert_equal({ "priority" => %w[normal high] }, priority_event.metadata["changes"])

    assignee_recording = RecordingStudioSupport::Tickets.update!(
      priority_recording, actor: @patron, assignee: @staff
    )
    assignee_event = latest_event(assignee_recording)
    assert_equal @patron, assignee_event.actor
    assert_equal priority_recording.recordable, assignee_event.previous_recordable
    assert_equal({ "assignee" => [nil, "#{@staff.class.name}:#{@staff.id}"] }, assignee_event.metadata["changes"])
  end

  test "an unchanged update does not record an event" do
    ticket = open_ticket!
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)

    assert_no_difference -> { recording.events.count } do
      RecordingStudioSupport::Tickets.update!(recording, actor: @staff, status: :open, priority: :normal)
    end
  end

  test "a second ticket on the same group is rejected" do
    ticket = open_ticket!
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    error = assert_raises(RecordingStudioSupport::Tickets::AlreadyExists) do
      RecordingStudioSupport::Tickets::Open.new(
        actor: @patron,
        subject: "Second ticket",
        body: "This thread already has one."
      ).send(:create_ticket!, group)
    end

    assert_equal "This conversation already has a ticket.", error.message
    assert_equal 1, RecordingStudioSupport::Tickets.ticket_recordings.where(parent_recording_id: group.id).count
  end

  private

  def open_ticket!
    RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Export failed #{SecureRandom.hex(4)}",
      body: "Export dies at 80%."
    )
  end

  def created_event(ticket)
    RecordingStudioSupport::Tickets.recording_for!(ticket).events.find_by!(action: "created")
  end

  def latest_event(recording)
    recording.events.order(occurred_at: :desc, created_at: :desc).first
  end
end
