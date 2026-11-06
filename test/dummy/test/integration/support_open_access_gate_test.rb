# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportOpenAccessGateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @staff = User.find_by!(email: "admin@admin.com")
    @staff.update!(admin: true) unless @staff.admin?

    @patron = RecordingStudioUser.create_user!(
      email: "open-gate-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @stranger = RecordingStudioUser.create_user!(
      email: "open-gate-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Stranger",
      time_zone: "UTC"
    )
  end

  test "requester can open their own ticket" do
    sign_in @patron

    assert_difference -> { RecordingStudioSupport::SupportTicket.count }, +1 do
      post "/help/messages", params: {
        ticket: {
          subject: "Quieter crop stuck",
          body: "The quieter crop is stuck.",
          priority: "normal"
        }
      }
    end

    ticket = RecordingStudioSupport::SupportTicket.order(:created_at).last
    assert_redirected_to "/help/messages/#{ticket.id}"
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)
    assert RecordingStudioSupport::Messages.group_owner?(group, @patron)
  end

  test "while a ticket is opening unrelated access grants still fail" do
    workspace = RecordingStudioSupport::Messages.support_workspace_root
    side_grant = nil
    stranger = @stranger
    patron = @patron

    opener = RecordingStudioSupport::Tickets::Open.new(
      actor: patron,
      subject: "Keep the gate narrow",
      body: "Do not skip other Accessible checks."
    )
    original = opener.method(:record_group!)
    opener.define_singleton_method(:record_group!) do |mount|
      side_grant = RecordingStudioAccessible.grant_access(
        recording: workspace,
        actor: stranger,
        role: :admin,
        manager_actor: patron
      )
      original.call(mount)
    end

    ticket = opener.call
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    assert side_grant.failure?, "grant_access on the workspace must fail while a ticket is opening"
    assert_match(/not authorized/i, side_grant.error.to_s)
    refute RecordingStudioAccessible.authorized?(
      actor: @stranger,
      recording: workspace,
      role: :admin
    )
    refute RecordingStudioAccessible.authorized?(
      actor: @stranger,
      recording: group,
      role: :view
    )
    assert RecordingStudioSupport::Messages.group_owner?(group, @patron)
  end

  test "staff only screens still forbidden for non staff" do
    sign_in @patron

    get "/admin/support/messages"
    assert_response :forbidden

    section = seeded_section("Getting started")
    get "/admin/support/sections/#{section.id}"
    assert_response :forbidden

    get "/admin/support/new"
    assert_response :forbidden
  end

  test "requester cannot open or see another persons ticket" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Mine",
      body: "Private note"
    )

    sign_in @stranger
    get "/help/messages/#{ticket.id}"
    assert_response :forbidden

    post "/help/messages", params: {
      ticket: {
        subject: "A different ticket",
        body: "I can still open my own.",
        priority: "normal"
      }
    }
    assert_response :redirect
    stranger_ticket = RecordingStudioSupport::SupportTicket.order(:created_at).last
    refute_equal ticket.id, stranger_ticket.id
    refute RecordingStudioSupport::Messages.group_owner?(
      RecordingStudioSupport::Tickets.group_recording_for(ticket),
      @stranger
    )
  end
end
