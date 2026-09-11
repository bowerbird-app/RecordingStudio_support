# frozen_string_literal: true

require "test_helper"

class SupportPagesDomainTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "pages-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    @root_recording = RecordingStudio.root_recording_for(
      Workspace.create!(name: "Pages #{SecureRandom.hex(4)}")
    )
    grant_admin!(@root_recording, @user)
    @section_recording = record_support_section(@root_recording)
  end

  teardown do
    Current.actor = nil
  end

  test "create and revise go through public helpers" do
    recording = RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Office hours",
      description: "When the desk is open.",
      icon: "clock",
      body: "Tuesday mornings.",
      actor: @user
    )
    original_id = recording.recordable_id
    assert_equal "When the desk is open.", recording.recordable.description
    assert_equal "clock", recording.recordable.icon

    RecordingStudioSupport::Pages.revise!(
      recording: recording,
      title: "Office hours",
      description: "Wednesday desk hours.",
      icon: "calendar-days",
      body: "Wednesday mornings.",
      actor: @user
    )

    recording.reload
    assert_not_equal original_id, recording.recordable_id
    assert_equal "Wednesday mornings.", recording.recordable.body
    assert_equal "Wednesday desk hours.", recording.recordable.description
    assert_equal "calendar-days", recording.recordable.icon
    assert_equal @section_recording, recording.parent_recording
  end

  test "page icon normalizes and clears like section icons" do
    recording = RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Icon check #{SecureRandom.hex(4)}",
      icon: "Credit_Card",
      body: "Body",
      actor: @user
    )
    assert_equal "credit-card", recording.recordable.icon

    revised = RecordingStudioSupport::Pages.revise!(
      recording: recording,
      title: recording.recordable.title,
      icon: "  ",
      body: recording.recordable.body,
      actor: @user
    )
    assert_nil revised.recordable.icon

    invalid = RecordingStudioSupport::SupportPage.new(title: "Nope", icon: "not a name!")
    refute invalid.valid?
    assert_includes invalid.errors[:icon].join, "Heroicons"
  end

  test "page views are logs not recordings" do
    recording = RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Printer jam",
      body: "Turn it off and on again.",
      actor: @user
    )

    assert_no_difference -> { RecordingStudio::Recording.count } do
      RecordingStudioSupport::PageView.record!(recording: recording, actor: @user)
    end

    assert_equal 1, RecordingStudioSupport::PageView.where(recording_id: recording.id).count
    refute_includes RecordingStudio.configuration.recordable_types, "RecordingStudioSupport::PageView"
  end

  test "for_root trigram search filters title and body" do
    RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "How do I sign in?",
      body: "Use the email you were given.",
      actor: @user
    )
    RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "How do I change my password?",
      body: "Pick a new one.",
      actor: @user
    )

    titles = lambda do |query|
      RecordingStudioSupport::Pages.for_root(@root_recording, query: query).map { |recording| recording.recordable.title }
    end

    assert_equal ["How do I sign in?"], titles.call("sign in")
    assert_equal ["How do I change my password?"], titles.call("Pick a new")
    assert_empty titles.call("no-such-help-page")
  end

  test "SupportPage.search uses pg_trgm backend" do
    RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Refund timeline",
      body: "Money returns in five days.",
      actor: @user
    )
    RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Shipping labels",
      body: "Print from the orders screen.",
      actor: @user
    )

    hits = RecordingStudioSupport::SupportPage.search("refund").map(&:title)

    assert_equal ["Refund timeline"], hits
    assert_equal :pg_trgm, RecordingStudioSearch::Registry.entry_for(RecordingStudioSupport::SupportPage).backend
    assert_equal %i[title body], RecordingStudioSearch::Registry.entry_for(RecordingStudioSupport::SupportPage).against
  end

  test "find_kept finds a page without the current root" do
    recording = RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Office Wi-Fi",
      body: "Ask the front desk.",
      actor: @user
    )

    found = RecordingStudioSupport::Pages.find_kept!(id: recording.id)
    admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))

    assert_equal recording.id, found.id
    refute RecordingStudioSupport::Sections.allowed_parent_root?(admin_root)
    assert RecordingStudioSupport::Sections.allowed_parent_root?(@root_recording)
    assert RecordingStudioSupport::Sections.allowed_parent_root?(
      RecordingStudioSupport::Sections.parent_root_for(admin_root)
    )
    assert_equal @section_recording, RecordingStudioSupport::Pages.default_section_for(@root_recording)
    assert RecordingStudioSupport::Pages.default_section_for(admin_root).present? ||
           RecordingStudioSupport::Sections.default_parent_root.blank?
  end

  test "public_indexable uses Publishable indexable and hides drafts" do
    token = SecureRandom.hex(4)
    draft_only = "zzdraft#{SecureRandom.hex(6)}"
    live = RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Live help #{token}",
      body: "Use the live token #{token}.",
      actor: @user
    )
    draft = RecordingStudioSupport::Pages.create!(
      parent_recording: @section_recording,
      title: "Draft help #{token}",
      body: "Hidden draft marker #{draft_only}.",
      actor: @user
    )

    publish!(live, slug: "live-help-#{token}", status: "published")
    publish!(draft, slug: "draft-help-#{token}", status: "draft")

    titles = RecordingStudioSupport::Pages.public_indexable.map(&:title)

    assert_includes titles, "Live help #{token}"
    refute_includes titles, "Draft help #{token}"
    assert_equal(
      [live.recordable.id],
      RecordingStudioSupport::Pages.public_indexable(query: "Live help #{token}").map(&:id)
    )
    assert_empty RecordingStudioSupport::Pages.public_indexable(query: draft_only)
    assert live.recordable.indexable?
    refute draft.recordable.indexable?
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
