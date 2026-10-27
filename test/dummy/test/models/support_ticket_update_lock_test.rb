# frozen_string_literal: true

require "test_helper"

class SupportTicketUpdateLockTest < ActiveSupport::TestCase
  setup do
    @patron = RecordingStudioUser.create_user!(
      email: "ticket-lock-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @staff = RecordingStudioUser.create_user!(
      email: "ticket-lock-staff-#{SecureRandom.hex(4)}@example.com",
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

  test "a stale recording keeps the other field from a concurrent edit" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Two editors #{SecureRandom.hex(4)}",
      body: "Please do not drop either change."
    )
    recording = RecordingStudioSupport::Tickets.recording_for!(ticket)
    stale = RecordingStudio::Recording.find(recording.id)
    stale.recordable

    RecordingStudioSupport::Tickets.update!(recording, actor: @staff, status: :waiting_on_customer)
    revised = RecordingStudioSupport::Tickets.update!(stale, actor: @staff, priority: :high)
    current = revised.recordable

    assert_equal "waiting_on_customer", current.status
    assert_equal "high", current.priority
    assert_equal ["priority"], revised.events.order(occurred_at: :desc).first.metadata["changes"].keys
  end
end
