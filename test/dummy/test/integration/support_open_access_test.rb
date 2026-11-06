# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportOpenAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @staff = User.find_by!(email: "admin@admin.com")
    @staff.update!(admin: true) unless @staff.admin?

    @patron = RecordingStudioUser.create_user!(
      email: "open-access-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @stranger = RecordingStudioUser.create_user!(
      email: "open-access-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Stranger",
      time_zone: "UTC"
    )

    @workspace = Workspace.order(:created_at).first
    @workspace_root = RecordingStudio.root_recording_for(@workspace)
    @mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: @patron)
  end

  test "requester ticket open still creates group staff grants ticket and first message" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Narrow gate",
      body: "Accessible checks stay on."
    )
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    assert RecordingStudioSupport::Messages.group_owner?(group, @patron)
    assert RecordingStudioSupport::Messages.staff_has_edit?(group, @staff)
    messages = RecordingStudioMessages.message_recordings(group)
    assert_equal 1, messages.count
    assert_equal "Accessible checks stay on.", messages.first.recordable.body
  end

  test "unrelated recordings stay denied inside the open gate" do
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @patron, mount: @mount) do
      group = RecordingStudioMessages.create_group(@mount, title: "First open", actor: @patron)
      assert RecordingStudioSupport::Messages.group_owner?(group, @patron)

      deny = RecordingStudioAccessible.grant_access(
        recording: @workspace_root,
        actor: @stranger,
        role: :view,
        manager_actor: @patron
      )
      assert deny.failure?, "grant_access on the workspace must still fail during open"
      assert_match(/not authorized/i, deny.error.to_s)
    end
  end

  test "create_group without the open gate is denied for a requester" do
    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.create_group(@mount, title: "No open gate", actor: @patron)
    end

    assert_match(/not authorized/i, error.message)
  end
end
