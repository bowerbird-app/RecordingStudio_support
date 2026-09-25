# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportMembershipLockTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @staff = User.find_by!(email: "admin@admin.com")
    @staff.update!(admin: true) unless @staff.admin?

    @patron = RecordingStudioUser.create_user!(
      email: "lock-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @stranger = RecordingStudioUser.create_user!(
      email: "lock-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Stranger",
      time_zone: "UTC"
    )

    RecordingStudioSupport::Messages::OpenAccessManagement.install!
    RecordingStudioMessages::MembershipLock.install_authorizer_wrap!
  end

  test "support mount is membership locked" do
    mount = RecordingStudioSupport::Messages.ensure_message_mount(actor: @patron)

    assert RecordingStudioMessages.membership_locked?(mount)
  end

  test "ticket open and staff sync succeed under the lock" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Lock proof",
      body: "Open under membership lock."
    )
    group = ticket.message_group_recording

    assert RecordingStudioMessages.membership_locked_for_group?(group)
    assert RecordingStudioSupport::Messages.group_owner?(group, @patron)
    assert RecordingStudioSupport::Messages.staff_has_edit?(group, @staff)

    RecordingStudioSupport::Messages.sync_staff_grants!(
      group_recording: group,
      manager_actor: @patron
    )
    assert RecordingStudioSupport::Messages.staff_has_edit?(group, @staff)
  end

  test "manage grant without bypass is denied on a ticket group" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "No invites",
      body: "Membership stays closed."
    )
    group = ticket.message_group_recording

    deny = RecordingStudioAccessible.grant_access(
      recording: group,
      actor: @stranger,
      role: :view,
      manager_actor: @patron
    )

    assert deny.failure?, "grant_access should fail without allow_membership_change"
    assert_match(/not authorized/i, deny.error.to_s)
  end

  test "ticket show omits plus access" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "No access button",
      body: "Header should stay clean."
    )

    sign_in @patron
    get "/help/messages/#{ticket.id}"

    assert_response :success
    refute_includes response.body, "+ Access"
    refute_match(/flat-pack--avatar/i, response.body)
  end

  test "staff desk omits plus access on a ticket conversation" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Staff desk lock",
      body: "Staff should not see Access either."
    )
    group = ticket.message_group_recording

    sign_in @staff
    get "/admin/support/messages", params: { group_id: group.id }

    assert_response :success
    refute_includes response.body, "+ Access"
    refute_match(/flat-pack--avatar/i, response.body)
  end
end
