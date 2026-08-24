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
  end

  teardown do
    Current.actor = nil
  end

  test "create and revise go through public helpers" do
    recording = RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
      title: "Office hours",
      body: "Tuesday mornings.",
      actor: @user
    )
    original_id = recording.recordable_id

    RecordingStudioSupport::Pages.revise!(
      recording: recording,
      title: "Office hours",
      body: "Wednesday mornings.",
      actor: @user
    )

    recording.reload
    assert_not_equal original_id, recording.recordable_id
    assert_equal "Wednesday mornings.", recording.recordable.body
    assert_equal @root_recording, recording.parent_recording
  end

  test "page views are logs not recordings" do
    recording = RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
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

  test "for_root ILIKE filters title and body" do
    RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
      title: "How do I sign in?",
      body: "Use the email you were given.",
      actor: @user
    )
    RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
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

  test "find_kept finds a page without the current root" do
    recording = RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
      title: "Office Wi-Fi",
      body: "Ask the front desk.",
      actor: @user
    )

    found = RecordingStudioSupport::Pages.find_kept!(id: recording.id)
    admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))

    assert_equal recording.id, found.id
    refute RecordingStudioSupport::Pages.allowed_parent_root?(admin_root)
    assert RecordingStudioSupport::Pages.allowed_parent_root?(@root_recording)
    assert RecordingStudioSupport::Pages.allowed_parent_root?(
      RecordingStudioSupport::Pages.parent_root_for(admin_root)
    )
  end

  test "public_indexable uses Publishable indexable and hides drafts" do
    token = SecureRandom.hex(4)
    live = RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
      title: "Live help #{token}",
      body: "Use the live token #{token}.",
      actor: @user
    )
    draft = RecordingStudioSupport::Pages.create!(
      root_recording: @root_recording,
      title: "Draft help #{token}",
      body: "Hidden draft token #{token}-draft.",
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
    assert_empty RecordingStudioSupport::Pages.public_indexable(query: "#{token}-draft")
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
