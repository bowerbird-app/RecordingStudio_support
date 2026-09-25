# frozen_string_literal: true

require "test_helper"

class SupportTicketModelTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb")
    @patron = RecordingStudioUser.create_user!(
      email: "ticket-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
  end

  test "open creates ticket group grants and initial message" do
    ticket = nil

    assert_difference -> { RecordingStudioSupport::SupportTicket.count }, +1 do
      ticket = RecordingStudioSupport::Tickets.open!(
        actor: @patron,
        subject: "Crop export failed",
        body: "Export dies at 80%.",
        priority: :high
      )
    end

    assert_equal "Crop export failed", ticket.subject
    assert_equal "high", ticket.priority
    assert_equal "open", ticket.status
    assert_nil ticket.assignee
    assert_nil ticket.resolved_at

    group = ticket.message_group_recording
    assert_not_nil group
    assert_equal "Crop export failed", group.recordable.title
    assert RecordingStudioSupport::Messages.group_owner?(group, @patron)

    messages = RecordingStudioMessages.message_recordings(group)
    assert_equal 1, messages.count
    assert_equal "Export dies at 80%.", messages.first.recordable.body
  end

  test "open is transactional on blank body" do
    assert_no_difference -> { RecordingStudioSupport::SupportTicket.count } do
      assert_no_difference -> { message_group_count_for(@patron) } do
        assert_raises(ArgumentError) do
          RecordingStudioSupport::Tickets.open!(
            actor: @patron,
            subject: "No body",
            body: ""
          )
        end
      end
    end
  end

  test "resolved_at tracks status" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Done soon",
      body: "Please close when fixed."
    )

    ticket.update!(status: :resolved)
    assert_not_nil ticket.resolved_at

    ticket.update!(status: :waiting_on_support)
    assert_nil ticket.resolved_at
  end

  test "subject and message_group_id are required" do
    ticket = RecordingStudioSupport::SupportTicket.new

    refute ticket.valid?
    assert_includes ticket.errors[:subject], "can't be blank"
    assert_includes ticket.errors[:message_group_id], "can't be blank"
  end

  private

  def message_group_count_for(actor)
    mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: actor)
    return 0 if mount.blank?

    RecordingStudioMessages.viewable_group_recordings(
      actor: actor,
      mount_recording: mount
    ).count { |group| RecordingStudioSupport::Messages.group_owner?(group, actor) }
  end
end
