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
    admin_support_tree(@staff)
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

  test "status and priority changes record an updated event with the diff" do
    ticket = open_ticket!
    original = ticket

    status_recording = nil
    assert_difference -> { RecordingStudioSupport::Tickets.recording_for!(ticket).events.count }, 1 do
      status_recording = RecordingStudioSupport::Tickets.update!(ticket, actor: @staff, status: :resolved)
    end
    status_event = latest_event(status_recording)
    assert_equal "updated", status_event.action
    assert_equal @staff, status_event.actor
    assert_equal original, status_event.previous_recordable
    assert_equal({ "status" => %w[open resolved] }, status_event.metadata["changes"])

    priority_recording = nil
    assert_difference -> { status_recording.events.count }, 1 do
      priority_recording = RecordingStudioSupport::Tickets.update!(
        status_recording, actor: @staff, priority: :high
      )
    end
    priority_event = latest_event(priority_recording)
    assert_equal @staff, priority_event.actor
    assert_equal status_recording.recordable, priority_event.previous_recordable
    assert_equal({ "priority" => %w[normal high] }, priority_event.metadata["changes"])
  end

  test "an unchanged update does not record an event" do
    ticket = open_ticket!
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)

    assert_no_difference -> { recording.events.count } do
      RecordingStudioSupport::Tickets.update!(recording, actor: @staff, status: :open, priority: :normal)
    end
  end

  test "one update can record several fields on a single event" do
    ticket = open_ticket!
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)

    assert_difference -> { recording.events.count }, 1 do
      recording = RecordingStudioSupport::Tickets.update!(
        recording,
        actor: @staff,
        status: :resolved,
        priority: :high
      )
    end

    assert_equal(
      {
        "status" => %w[open resolved],
        "priority" => %w[normal high]
      },
      latest_event(recording).metadata["changes"]
    )
  end

  test "find bang resolves the recording and older snapshots until the ticket is trashed" do
    ticket = open_ticket!
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)
    first_id = ticket.id
    second = RecordingStudioSupport::Tickets.update!(recording, actor: @staff, priority: :high)
    second_id = second.recordable.id
    third = RecordingStudioSupport::Tickets.update!(second, actor: @staff, status: :waiting_on_support)
    current = third.recordable

    [recording.id, first_id, second_id, current.id].each do |id|
      assert_equal current.id, RecordingStudioSupport::Tickets.find!(id).id
    end

    third.update!(trashed_at: Time.current)

    [recording.id, first_id, second_id, current.id].each do |id|
      assert_raises(ActiveRecord::RecordNotFound) { RecordingStudioSupport::Tickets.find!(id) }
    end
  end

  test "a second ticket on the same group is rejected" do
    ticket = open_ticket!
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)
    opener = RecordingStudioSupport::Tickets::Open.new(
      actor: @patron,
      subject: "Second ticket",
      body: "This thread already has one."
    )

    error = assert_raises(RecordingStudioSupport::Tickets::AlreadyExists) do
      opener.send(:create_group!, recording)
    end

    assert_equal "This conversation already has a ticket.", error.message
    assert_equal recording.id, RecordingStudioSupport::Tickets.recording_for!(ticket).id
  end

  test "a trashed ticket allows a second ticket on the thread" do
    ticket = open_ticket!
    RecordingStudioSupport::Tickets.recording_for!(ticket).update!(trashed_at: Time.current)
    second = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Second ticket #{SecureRandom.hex(4)}",
      body: "The first one is gone."
    )

    assert_not_equal ticket.id, second.id
    assert RecordingStudioSupport::Tickets.group_recording_for(second)
    assert_nil RecordingStudioSupport::Tickets.group_recording_for(ticket)
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
