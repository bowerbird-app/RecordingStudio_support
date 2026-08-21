# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class RecordingStudioDeclarationsTest < ActiveSupport::TestCase
  test "dummy recordable declarations validate and expose parent/root introspection" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal %w[AdminRoot Workspace], RecordingStudio.root_recordable_types.sort
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for("Folder")
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for(Page)
    assert_equal ["Workspace"], RecordingStudio.allowed_parent_types_for("RecordingStudioSupport::SupportPage")
    assert_equal "Support page", RecordingStudio.recordable_type_label("RecordingStudioSupport::SupportPage")
    refute RecordingStudio.root_allowed?("RecordingStudioSupport::SupportPage")
  end

  test "root recordable creates a root recording" do
    workspace = Workspace.create!(name: unique_name("Root Workspace"))

    root_recording = RecordingStudio.root_recording_for(workspace)

    assert_predicate root_recording, :persisted?
    assert_equal workspace, root_recording.recordable
    assert_nil root_recording.parent_recording_id
    assert_equal root_recording.id, root_recording.root_recording_id
  end

  test "allowed child can be recorded under a workspace root" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Child Workspace")))
    folder = Folder.new(name: unique_name("Allowed Folder"))

    event = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording
    )

    assert_equal folder, event.recording.recordable
    assert_equal root_recording, event.recording.parent_recording
  end

  test "page can be recorded under allowed workspace and folder parents" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Page Workspace")))
    folder_recording = record_child(Folder.new(name: unique_name("Page Folder")), root_recording, root_recording)

    workspace_page_recording = record_child(
      Page.new(title: unique_name("Workspace Page")),
      root_recording,
      root_recording
    )
    folder_page_recording = record_child(Page.new(title: unique_name("Folder Page")), root_recording, folder_recording)

    assert_equal root_recording, workspace_page_recording.parent_recording
    assert_equal folder_recording, folder_page_recording.parent_recording
  end

  test "child recordable cannot be created as a root" do
    folder = Folder.create!(name: unique_name("Root Rejected Folder"))

    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(folder)
    end
  end

  test "parentless child under an existing root is invalid" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Parentless Workspace")))
    folder = Folder.create!(name: unique_name("Parentless Folder"))
    recording = RecordingStudio::Recording.new(root_recording: root_recording, recordable: folder)

    assert_not recording.valid?
    assert_includes recording.errors[:parent_recording_id].join, "cannot be blank"
  end

  test "page cannot be recorded under another page" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Invalid Page Workspace")))
    page_recording = record_child(Page.new(title: unique_name("Parent Page")), root_recording, root_recording)

    error = assert_raises(RecordingStudio::InvalidParent) do
      record_child(Page.new(title: unique_name("Nested Page")), root_recording, page_recording)
    end
    assert_equal "Page cannot be recorded under Page", error.message
  end

  test "support page can be recorded under the host workspace root" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Support Workspace")))

    assert RecordingStudio.parent_allowed?(
      child_type: "RecordingStudioSupport::SupportPage",
      parent_recording: root_recording
    )

    recording = root_recording.record(RecordingStudioSupport::SupportPage) do |page|
      page.title = unique_name("How do I reset my password?")
      page.body = "Ask a teammate who already has access."
    end

    assert_equal root_recording, recording.parent_recording
    assert_equal root_recording, recording.root_recording
    assert_kind_of RecordingStudioSupport::SupportPage, recording.recordable
    assert_equal "recording_studio_support_pages", recording.recordable.class.table_name
  end

  test "support page cannot be created as a root" do
    support_page = RecordingStudioSupport::SupportPage.create!(
      title: unique_name("Root Rejected Support Page")
    )

    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(support_page)
    end
  end

  test "support page cannot be recorded under a folder" do
    workspace = Workspace.create!(name: unique_name("Support Parent Workspace"))
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder_recording = record_child(Folder.new(name: unique_name("Support Folder")), root_recording, root_recording)

    refute RecordingStudio.parent_allowed?(
      child_type: "RecordingStudioSupport::SupportPage",
      parent_recording: folder_recording
    )

    error = assert_raises(RecordingStudio::InvalidParent) do
      root_recording.record(
        RecordingStudioSupport::SupportPage,
        parent_recording: folder_recording
      ) do |page|
        page.title = unique_name("Nested Support Page")
      end
    end

    assert_equal "RecordingStudioSupport::SupportPage cannot be recorded under Folder", error.message
  end

  test "support page revise creates a new snapshot" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Revise Workspace")))
    recording = root_recording.record(RecordingStudioSupport::SupportPage) do |page|
      page.title = unique_name("Office hours")
      page.body = "Tuesday mornings."
    end
    original_id = recording.recordable_id

    recording.log_event!(action: "viewed")
    root_recording.revise(recording) do |page|
      page.body = "Wednesday mornings."
    end

    recording.reload
    assert_not_equal original_id, recording.recordable_id
    assert_equal "Wednesday mornings.", recording.recordable.body
    assert_equal 1, recording.events.where(action: "viewed").count
  end

  test "accessible is enabled on workspace and admin root" do
    assert RecordingStudio.capability_enabled?(:accessible, for: "Workspace")
    assert RecordingStudio.capability_enabled?(:accessible, for: "AdminRoot")
    refute RecordingStudio.capability_enabled?(:accessible, for: "Folder")
    refute RecordingStudio.capability_enabled?(:accessible, for: "Page")
    refute RecordingStudio.capability_enabled?(:accessible, for: "RecordingStudioSupport::SupportPage")
  end

  test "attachable trashable orderable and publishable are enabled on support pages only" do
    %i[attachable trashable orderable publishable].each do |capability|
      assert RecordingStudio.capability_enabled?(capability, for: "RecordingStudioSupport::SupportPage"),
             "#{capability} should be enabled on SupportPage"
      refute RecordingStudio.capability_enabled?(capability, for: "Workspace"),
             "#{capability} should not be enabled on Workspace"
      refute RecordingStudio.capability_enabled?(capability, for: "Folder"),
             "#{capability} should not be enabled on Folder"
      refute RecordingStudio.capability_enabled?(capability, for: "Page"),
             "#{capability} should not be enabled on Page"
    end

    assert_equal(
      ["RecordingStudioAttachable::Attachment"],
      RecordingStudio.capability_options(:orderable, for: "RecordingStudioSupport::SupportPage")[:allows]
    )
    assert_equal ["image/*"],
                 RecordingStudio.capability_options(:attachable, for: "RecordingStudioSupport::SupportPage")[:allowed_content_types]
    assert_equal %i[image],
                 RecordingStudio.capability_options(:attachable, for: "RecordingStudioSupport::SupportPage")[:enabled_attachment_kinds]
  end

  test "publishable to options are registered on support pages only" do
    publishable_options = RecordingStudio.capability_options(
      :publishable,
      for: "RecordingStudioSupport::SupportPage"
    )
    assert_equal "recording_studio_support/public_pages", publishable_options[:public_controller]
    assert_equal :show, publishable_options[:public_action]
    assert_equal "recording_studio_publishable/application", publishable_options[:public_layout]
    assert_equal "/help/:uuid/:slug", publishable_options[:path]
  end

  private

  def record_child(recordable, root_recording, parent_recording)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
