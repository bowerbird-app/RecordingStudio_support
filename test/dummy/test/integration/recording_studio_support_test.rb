# frozen_string_literal: true

require "test_helper"

class RecordingStudioSupportTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "AdminRoot", "Workspace" ], RecordingStudio.root_recordable_types.sort
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
    assert_equal [ "Workspace" ], RecordingStudio.allowed_parent_types_for("RecordingStudioSupport::SupportPage")
    assert_equal "Support page", RecordingStudio.recordable_type_label(RecordingStudioSupport::SupportPage)
  end

  test "dummy app schema keeps accessible grants and support pages" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    assert connection.table_exists?(:recording_studio_support_pages)
    assert connection.table_exists?(:recording_studio_support_page_views)
    assert connection.table_exists?(:admin_roots)
    assert connection.column_exists?(:recording_studio_support_pages, :title)
    assert connection.column_exists?(:recording_studio_support_pages, :body)
    refute connection.column_exists?(:recording_studio_support_pages, :updated_at)
    assert connection.table_exists?(:recording_studio_attachable_attachments)
    assert connection.table_exists?(:active_storage_blobs)
    assert connection.table_exists?(:recording_studio_trashable_retention_settings)
    assert connection.table_exists?(:recording_studio_publishable_publishables)
    assert connection.column_exists?(:recording_studio_recordings, :trash_root)
    assert connection.column_exists?(:recording_studio_recordings, :recording_studio_orderable_position)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    accessible_workspace = Workspace.find_by!(name: "Client Workspace")
    private_workspace = Workspace.find_by!(name: "Private Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    sign_in_page = RecordingStudioSupport::SupportPage.find_by!(title: "How do I sign in?")
    password_page = RecordingStudioSupport::SupportPage.find_by!(title: "How do I change my password?")
    admin_root = AdminRoot.find_by!(name: "Admin")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    accessible_root_recording = RecordingStudio::Recording.find_by!(recordable: accessible_workspace)
    private_root_recording = RecordingStudio::Recording.find_by!(recordable: private_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)
    support_page_recording = RecordingStudio::Recording.find_by!(recordable: sign_in_page)
    password_page_recording = RecordingStudio::Recording.find_by!(recordable: password_page)
    admin_root_recording = RecordingStudio::Recording.find_by!(recordable: admin_root)

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil accessible_root_recording.parent_recording_id
    assert_nil private_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal root_recording, support_page_recording.parent_recording
    assert_equal root_recording, support_page_recording.root_recording
    assert_equal root_recording, password_page_recording.parent_recording
    assert_nil admin_root_recording.parent_recording_id
    assert_equal 3, Workspace.count
    assert_equal 1, AdminRoot.count
    assert_operator RecordingStudioSupport::SupportPage.count, :>=, 2
    assert support_page_recording.images.any?
    assert sign_in_page.indexable?
    refute password_page.indexable?
    assert support_page_recording.currently_published?
    refute password_page_recording.currently_published?
    assert_operator RecordingStudioSupport::PageView.count, :>=, 1
    assert_equal :admin, RecordingStudioAccessible.role_for(
      actor: User.find_by!(email: "admin@admin.com"),
      recording: root_recording
    )
    assert_equal :admin, RecordingStudioAccessible.role_for(
      actor: User.find_by!(email: "admin@admin.com"),
      recording: admin_root_recording
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        assert_no_difference -> { RecordingStudioSupport::SupportPage.count } do
          assert_no_difference -> { RecordingStudioSupport::PageView.count } do
            load Rails.root.join("db/seeds.rb").to_s
          end
        end
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace opts into accessible without enabling it on support pages" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))

    refute_includes workspace_source, "Capabilities::Example"
    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    assert RecordingStudio.capability_enabled?(:accessible, for: AdminRoot)
    refute RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
    refute RecordingStudio.capability_enabled?(:accessible, for: RecordingStudioSupport::SupportPage)
    assert RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioSupport::SupportPage)
    assert RecordingStudio.capability_enabled?(:trashable, for: RecordingStudioSupport::SupportPage)
    assert RecordingStudio.capability_enabled?(:orderable, for: RecordingStudioSupport::SupportPage)
    assert RecordingStudio.capability_enabled?(:publishable, for: RecordingStudioSupport::SupportPage)
    refute RecordingStudio.capability_enabled?(:attachable, for: Folder)
    refute RecordingStudio.capability_enabled?(:trashable, for: Folder)
    refute RecordingStudio.capability_enabled?(:orderable, for: Folder)
    refute RecordingStudio.capability_enabled?(:attachable, for: Page)
    refute RecordingStudio.capability_enabled?(:trashable, for: Page)
    refute RecordingStudio.capability_enabled?(:orderable, for: Page)
    refute RecordingStudio.capability_enabled?(:publishable, for: Folder)
    refute RecordingStudio.capability_enabled?(:publishable, for: Page)
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end
end
