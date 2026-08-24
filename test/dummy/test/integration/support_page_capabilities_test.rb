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
    @page_recording = @root_recording.record(RecordingStudioSupport::SupportPage) do |page|
      page.title = "How do I attach a screenshot?"
      page.body = "Add the picture under this article."
    end
  end

  teardown do
    Current.actor = nil
  end

  test "support page attaches an image child through import_attachment" do
    attachment_recording = @page_recording.import_attachment(
      io: StringIO.new(ONE_PIXEL_PNG),
      filename: "sign-in.png",
      content_type: "image/png",
      actor: @user
    )

    assert_equal "RecordingStudioAttachable::Attachment", attachment_recording.recordable_type
    assert_equal @page_recording, attachment_recording.parent_recording
    assert_equal @root_recording, attachment_recording.root_recording
    assert_equal "image", attachment_recording.recordable.attachment_kind
    assert_equal "sign-in.png", attachment_recording.recordable.original_filename
    assert attachment_recording.recordable.file.attached?
    assert @page_recording.has_attachments?(kind: :images)
    assert_equal [attachment_recording.id], @page_recording.images.map(&:id)
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

  test "support page reorders image siblings through orderable helpers" do
    first = import_png("first.png")
    second = import_png("second.png")

    @page_recording.recording_studio_orderable_reorder!(
      ordered_recording_ids: [second.id, first.id],
      actor: @user
    )

    ordered_ids = @page_recording.recording_studio_orderable_children.map(&:id)
    assert_equal [second.id, first.id], ordered_ids
    assert_equal 1, @page_recording.events.where(action: "reordered").count

    @page_recording.recording_studio_orderable_move!(first, to_index: 0, actor: @user)

    assert_equal [first.id, second.id], @page_recording.recording_studio_orderable_children.map(&:id)
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

  def import_png(filename)
    @page_recording.import_attachment(
      io: StringIO.new(ONE_PIXEL_PNG),
      filename: filename,
      content_type: "image/png",
      actor: @user
    )
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
