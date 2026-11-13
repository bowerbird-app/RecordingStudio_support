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
    assert_nil ticket.resolved_at

    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
    assert_not_nil group
    assert_equal "Crop export failed", group.recordable.title
    assert_equal [ "edit" ], direct_access_roles(group, @patron)
    assert_empty direct_access_roles(group, User.find_by!(email: "admin@admin.com"))
    assert RecordingStudioAccessible.authorized?(
      actor: User.find_by!(email: "admin@admin.com"),
      recording: group,
      role: :view
    )

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

    ticket = revise_support_ticket!(ticket, status: :resolved)
    assert_not_nil ticket.resolved_at

    ticket = revise_support_ticket!(ticket, status: :open)
    assert_nil ticket.resolved_at
  end

  test "status is open or resolved" do
    ticket = RecordingStudioSupport::SupportTicket.new(subject: "Crop export failed", status: "waiting_on_customer")

    refute ticket.valid?
    assert_includes ticket.errors[:status], "is not included in the list"
    assert_equal %w[open resolved], RecordingStudioSupport::SupportTicket::STATUSES
  end

  test "subject is required" do
    ticket = RecordingStudioSupport::SupportTicket.new

    refute ticket.valid?
    assert_includes ticket.errors[:subject], "can't be blank"
    refute_includes ticket.errors.attribute_names, :message_group_id
  end

  private

  def message_group_count_for(actor)
    RecordingStudioSupport::Tickets.for_actor(actor).count
  end
end
