# frozen_string_literal: true

require "test_helper"

class SupportSectionsDomainTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "sections-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    @root_recording = RecordingStudio.root_recording_for(
      Workspace.create!(name: "Sections #{SecureRandom.hex(4)}")
    )
    grant_admin!(@root_recording, @user)
  end

  teardown do
    Current.actor = nil
  end

  test "page cannot nest under workspace and section cannot nest" do
    section = record_support_section(@root_recording, title: "Getting started")

    refute RecordingStudio.parent_allowed?(
      child_type: "RecordingStudioSupport::SupportPage",
      parent_recording: @root_recording
    )
    refute RecordingStudio.parent_allowed?(
      child_type: "RecordingStudioSupport::SupportSection",
      parent_recording: section
    )

    assert_raises(RecordingStudio::InvalidParent) do
      @root_recording.record(RecordingStudioSupport::SupportPage) do |page|
        page.title = "Orphan page"
      end
    end

    assert_raises(RecordingStudio::InvalidParent) do
      @root_recording.record(
        RecordingStudioSupport::SupportSection,
        parent_recording: section
      ) do |nested|
        nested.title = "Nested"
      end
    end
  end

  test "moveable moves a page between sections" do
    getting_started = record_support_section(@root_recording, title: "Getting started")
    billing = record_support_section(@root_recording, title: "Billing")
    page = record_support_page(
      @root_recording,
      getting_started,
      title: "How do I sign in?",
      body: "Use the email you were given."
    )

    moved = RecordingStudioSupport::Pages.move!(
      recording: page,
      parent_recording: billing,
      actor: @user
    )

    assert_equal billing.id, moved.parent_recording_id
    assert_equal @root_recording.id, moved.root_recording_id
    assert_equal 1, moved.events.where(action: "moved").count

    assert_raises(RecordingStudio::InvalidParent) do
      RecordingStudioSupport::Pages.move!(
        recording: page,
        parent_recording: @root_recording,
        actor: @user
      )
    end
  end

  test "orderable on a section sorts its pages" do
    section = record_support_section(@root_recording, title: "Getting started")
    first = record_support_page(@root_recording, section, title: "First page")
    second = record_support_page(@root_recording, section, title: "Second page")

    section.recording_studio_orderable_reorder!(
      ordered_recording_ids: [second.id, first.id],
      actor: @user
    )

    assert_equal [second.id, first.id], section.recording_studio_orderable_children.map(&:id)
  end

  test "trashing a section cascade-trashes its pages and empty sections trash cleanly" do
    occupied = record_support_section(@root_recording, title: "Getting started")
    empty = record_support_section(@root_recording, title: "Billing")
    page = record_support_page(@root_recording, occupied, title: "How do I sign in?")

    occupied.recording_studio_trashable_trash!(actor: @user)
    page.reload
    assert occupied.trashed_at
    assert page.trashed_at, "Trashable subtree trash hides pages under a trashed section"

    empty.recording_studio_trashable_trash!(actor: @user)
    assert empty.trashed_at
    assert empty.trash_root
  end

  test "public section show hides drafts" do
    section = record_support_section(@root_recording, title: "Getting started")
    live = record_support_page(@root_recording, section, title: "Live in section")
    draft = record_support_page(@root_recording, section, title: "Draft in section")
    publish!(live, slug: "live-in-section-#{SecureRandom.hex(4)}", status: "published")
    publish!(draft, slug: "draft-in-section-#{SecureRandom.hex(4)}", status: "draft")

    titles = RecordingStudioSupport::Pages.public_for_section(section).map(&:title)
    assert_includes titles, "Live in section"
    refute_includes titles, "Draft in section"

    staff_counts = RecordingStudioSupport::Pages.kept_count_by_section([section])
    public_counts = RecordingStudioSupport::Pages.public_count_by_section([section])
    assert_equal 2, staff_counts.fetch(section.id)
    assert_equal 1, public_counts.fetch(section.id)
  end

  private

  def publish!(page_recording, slug:, status:)
    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: page_recording,
      actor: @user,
      attributes: { slug: slug, status: status }
    )
    raise result.error if result.failure?
  end

  def grant_admin!(recording, actor)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :admin,
      manager_actor: actor
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
