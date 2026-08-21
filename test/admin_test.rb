# frozen_string_literal: true

require "test_helper"

class AdminTest < Minitest::Test
  def test_support_section_is_help_not_jargon
    assert_equal "support", RecordingStudioSupport::Admin::Section.key
    assert_equal "Help", RecordingStudioSupport::Admin::Section.title
    refute_includes RecordingStudioSupport::Admin::Section.title, "recordable"
    refute_includes RecordingStudioSupport::Admin::Section.subtitle, "recordable"
  end

  def test_help_pages_screen_lists_pages
    assert_equal "help_pages", RecordingStudioSupport::Admin::PagesScreen.key
    assert_equal "Help pages", RecordingStudioSupport::Admin::PagesScreen.title
  end

  def test_queries_build_authenticated_page_paths
    recording = Struct.new(:id).new("page-123")

    assert_equal "/support/page-123", RecordingStudioSupport::Admin::Queries.page_path(recording)
  end

  def test_register_is_safe_when_admin_is_defined
    called = []
    RecordingStudioAdmin.stub(:register_section, ->(section) { called << section }) do
      RecordingStudioAdmin.stub(:register_screen, ->(screen) { called << screen }) do
        RecordingStudioAdmin.stub(:register_widget, ->(widget) { called << widget }) do
          RecordingStudioSupport::Admin.register!
        end
      end
    end

    assert_includes called, RecordingStudioSupport::Admin::Section
    assert_includes called, RecordingStudioSupport::Admin::PagesScreen
    assert_equal 5, called.size
  end
end
