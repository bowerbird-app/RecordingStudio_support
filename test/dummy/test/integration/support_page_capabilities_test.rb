# frozen_string_literal: true

require "test_helper"

class SupportPageCapabilitiesTest < ActiveSupport::TestCase
  ONE_PIXEL_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  ).freeze

  setup do
    @user = User.create!(
      email: "editor-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    @root_recording = RecordingStudio.root_recording_for(
      Workspace.create!(name: "Support mixins #{SecureRandom.hex(4)}")
    )
    grant_admin!(@root_recording, @user)
    @section_recording = record_support_section(@root_recording)
    @page_recording = record_support_page(
      @root_recording,
      @section_recording,
      title: "How do I attach a screenshot?",
      body: "Add the picture in the article."
    )
  end

  teardown do
    Current.actor = nil
  end

  test "support page trash and restore go through trashable helpers" do
    @page_recording.recording_studio_trashable_trash!(actor: @user)

    assert @page_recording.trashed_at
    assert @page_recording.trash_root
    assert_equal 1, @page_recording.events.where(action: "trashed").count

    @page_recording.recording_studio_trashable_restore!(actor: @user)

    assert_nil @page_recording.trashed_at
    refute @page_recording.trash_root
    assert_equal 1, @page_recording.events.where(action: "restored").count
  end

  test "folder and page do not get support mixins just because the gems are installed" do
    folder_recording = @root_recording.record(Folder) { |folder| folder.name = "Product Docs" }
    page_recording = @root_recording.record(Page, parent_recording: folder_recording) do |page|
      page.title = "Getting Started"
    end

    refute RecordingStudio.capability_enabled?(:attachable, for: Folder)
    refute RecordingStudio.capability_enabled?(:trashable, for: Folder)
    refute RecordingStudio.capability_enabled?(:orderable, for: Folder)
    refute RecordingStudio.capability_enabled?(:attachable, for: Page)
    refute RecordingStudio.capability_enabled?(:trashable, for: Page)
    refute RecordingStudio.capability_enabled?(:orderable, for: Page)
    refute RecordingStudio.capability_enabled?(:publishable, for: Folder)
    refute RecordingStudio.capability_enabled?(:publishable, for: Page)
    assert RecordingStudio.capability_enabled?(:publishable, for: RecordingStudioSupport::SupportPage)
    refute RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioSupport::SupportPage)

    error = assert_raises(RecordingStudio::CapabilityDisabled) do
      folder_recording.import_attachment(
        io: StringIO.new(ONE_PIXEL_PNG),
        filename: "folder.png",
        content_type: "image/png",
        actor: @user
      )
    end
    assert_match(/attachable/, error.message)

    error = assert_raises(RecordingStudio::CapabilityDisabled) do
      page_recording.recording_studio_trashable_trash!(actor: @user)
    end
    assert_match(/trashable/, error.message)
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
