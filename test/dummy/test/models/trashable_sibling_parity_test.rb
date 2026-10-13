# frozen_string_literal: true

require "test_helper"

class TrashableSiblingParityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "trashable-parity-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    @root_recording = RecordingStudio.root_recording_for(
      Workspace.create!(name: "Trashable parity #{SecureRandom.hex(4)}")
    )
    grant_admin!(@root_recording, @user)
  end

  teardown do
    Current.actor = nil
  end

  test "kept page and section scopes match recording_studio_trashable_active" do
    section = record_support_section(@root_recording, title: "Live section")
    kept_page = record_support_page(@root_recording, section, title: "Kept page")
    trashed_page = record_support_page(@root_recording, section, title: "Trashed page")
    trashed_page.recording_studio_trashable_trash!(actor: @user)

    other_section = record_support_section(@root_recording, title: "Gone section")
    other_section.recording_studio_trashable_trash!(actor: @user)

    page_ids = RecordingStudioSupport::Pages.kept_pages(@root_recording).pluck(:id)
    section_ids = RecordingStudioSupport::Sections.kept_sections(@root_recording).pluck(:id)
    active_page_ids = RecordingStudio::Recording.where(
      root_recording_id: @root_recording.id,
      recordable_type: RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
    ).recording_studio_trashable_active.pluck(:id)
    active_section_ids = RecordingStudio::Recording.where(
      root_recording_id: @root_recording.id,
      parent_recording_id: @root_recording.id,
      recordable_type: RecordingStudioSupport::Sections::SUPPORT_SECTION_TYPE
    ).recording_studio_trashable_active.pluck(:id)

    assert_equal active_page_ids.sort, page_ids.sort
    assert_equal active_section_ids.sort, section_ids.sort
    assert_includes page_ids, kept_page.id
    refute_includes page_ids, trashed_page.id
    assert_includes section_ids, section.id
    refute_includes section_ids, other_section.id

    assert kept_page.recording_studio_trashable_kept?
    assert trashed_page.reload.recording_studio_trashable_trashed?
  end

  test "section slug join uses kept_sql and ignores trashed section slugs" do
    table = RecordingStudio::Recording.table_name
    expected_kept = RecordingStudio::Recording.recording_studio_trashable_kept_sql(table)
    join_sql = RecordingStudioSupport::SupportSection.current_kept_join_sql

    assert_includes join_sql, expected_kept
    refute_match(/#{Regexp.escape(table)}\.trashed_at\s+IS\s+NULL/, join_sql)

    title = "Parity billing #{SecureRandom.hex(4)}"
    expected_slug = title.parameterize
    live = record_support_section(@root_recording, title: title)
    assert_equal expected_slug, live.recordable.slug

    live.recording_studio_trashable_trash!(actor: @user)
    refute RecordingStudioSupport::SupportSection.slug_taken?(expected_slug),
           "trashed section slug should be free via kept_sql join"

    reused = record_support_section(@root_recording, title: title)
    assert_equal expected_slug, reused.recordable.slug
    assert_equal expected_kept, RecordingStudio::Recording.recording_studio_trashable_kept_sql(table)
  end


  test "api workspace lookup uses trashable_active and rejects trashed roots" do
    assert_equal @root_recording.id,
                 RecordingStudioSupport::Api::Lookup.workspace!(id: @root_recording.id).id

    RecordingStudioTrashable.void_recording!(@root_recording, time: Time.current)
    assert @root_recording.reload.recording_studio_trashable_trashed?

    error = assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioSupport::Api::Lookup.workspace!(id: @root_recording.id)
    end
    assert_equal "Parent resource was not found", error.message
  end

  test "admin kept page recordings exclude trashed rows via trashable_active" do
    section = record_support_section(@root_recording, title: "Docs")
    kept = record_support_page(@root_recording, section, title: "Kept admin page")
    trashed = record_support_page(@root_recording, section, title: "Trashed admin page")
    trashed.recording_studio_trashable_trash!(actor: @user)

    ids = RecordingStudioSupport::Admin::Queries.kept_page_recordings.pluck(:id)
    assert_includes ids, kept.id
    refute_includes ids, trashed.id
  end

  private

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

