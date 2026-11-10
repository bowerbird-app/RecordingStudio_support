# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SupportCenterTreeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @staff = User.find_by!(email: "admin@admin.com")
    @patron = RecordingStudioUser.create_user!(
      email: "center-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    @stranger = RecordingStudioUser.create_user!(
      email: "center-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Sam",
      last_name: "Stranger",
      time_zone: "UTC"
    )
  end

  test "ticket parent is the support center and the group is tagged" do
    ticket = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Tagged thread",
      body: "Link by tag, not parent."
    )
    ticket_recording = RecordingStudioSupport::Tickets.recording_for!(ticket)
    group = RecordingStudioSupport::Tickets.group_recording_for(ticket)

    assert_equal "RecordingStudioSupport::SupportCenter", ticket_recording.parent_recording.recordable_type
    assert_equal RecordingStudioSupport::SupportCenters.current.id, ticket_recording.parent_recording_id
    refute_equal group.id, ticket_recording.parent_recording_id

    mount = RecordingStudioSupport::Messages.ensure_message_mount
    tagged = RecordingStudioMessages.tagged_group_recordings(
      mount_recording: mount,
      tags: { RecordingStudioSupport::Tickets::TAG_KEY => ticket_recording }
    )
    assert_includes tagged, group
    assert_equal group.id, RecordingStudioSupport::Tickets.tickets_by_group_id([group.id]).keys.first
  end

  test "customer sees only their own ticket thread" do
    mine = RecordingStudioSupport::Tickets.open!(
      actor: @patron,
      subject: "Mine only",
      body: "Keep this private."
    )
    RecordingStudioSupport::Tickets.open!(
      actor: @stranger,
      subject: "Someone else",
      body: "Not yours."
    )

    sign_in @patron
    get "/help/messages"
    assert_response :success
    assert_includes response.body, "Mine only"
    refute_includes response.body, "Someone else"

    get "/help/messages/#{mine.id}"
    assert_response :success

    other = RecordingStudioSupport::Tickets.for_actor(@stranger).first
    get "/help/messages/#{other.id}"
    assert_response :forbidden
  end

  test "non staff get forbidden on staff screens" do
    sign_in @patron
    get "/admin/support/messages"
    assert_response :forbidden
  end

  test "staff access comes from accessible grants not user admin" do
    granted = User.find_by!(email: "admin@admin.com")
    admin_flagged = RecordingStudioUser.create_user!(
      email: "flagged-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Flag",
      last_name: "Admin",
      time_zone: "UTC"
    )
    admin_flagged.update!(admin: true) if admin_flagged.respond_to?(:admin=)

    assert RecordingStudioSupport::Messages.staff_actor?(granted)
    refute RecordingStudioSupport::Messages.staff_actor?(admin_flagged)
    refute RecordingStudioSupport::Messages.staff_actor?(@patron)

    sign_in admin_flagged
    get "/admin/support/messages"
    assert_response :forbidden

    sign_out admin_flagged
    sign_in granted
    get "/admin/support/messages"
    assert_response :success
  end

  test "public help shows published articles and drafts 404" do
    published = seeded_page("How do I sign in?")
    draft = seeded_page("How do I change my password?")

    get "/help"
    assert_response :success
    assert_includes response.body, "Getting started"
    refute_includes response.body, "How do I change my password?"

    get published.recordable.published_url
    assert_response :success
    assert_includes response.body, "Open the sign-in page"

    get "/help/#{draft.publishable_child_recording.id}/how-do-i-change-my-password"
    assert_response :not_found
  end
end
