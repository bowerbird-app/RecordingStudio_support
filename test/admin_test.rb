# frozen_string_literal: true

require "test_helper"

class AdminTest < Minitest::Test
  def test_support_section_is_help_not_jargon
    assert_equal "support", RecordingStudioSupport::Admin::Section.key
    assert_equal "Help", resolve_admin_copy(RecordingStudioSupport::Admin::Section.title)
    assert_equal "Pages people use when they get stuck.",
                 resolve_admin_copy(RecordingStudioSupport::Admin::Section.subtitle)
    refute_includes resolve_admin_copy(RecordingStudioSupport::Admin::Section.title), "recordable"
    refute_includes resolve_admin_copy(RecordingStudioSupport::Admin::Section.subtitle), "recordable"
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

  def test_section_copy_follows_configuration
    previous_title = RecordingStudioSupport.configuration.admin_help_title
    previous_subtitle = RecordingStudioSupport.configuration.admin_help_subtitle
    RecordingStudioSupport.configuration.admin_help_title = "Guides"
    RecordingStudioSupport.configuration.admin_help_subtitle = "Staff view of those answers."

    assert_equal "Guides", resolve_admin_copy(RecordingStudioSupport::Admin::Section.title)
    assert_equal "Staff view of those answers.",
                 resolve_admin_copy(RecordingStudioSupport::Admin::Section.subtitle)
  ensure
    RecordingStudioSupport.configuration.admin_help_title = previous_title
    RecordingStudioSupport.configuration.admin_help_subtitle = previous_subtitle
  end

  private

  def resolve_admin_copy(value)
    value.respond_to?(:call) ? value.call(nil) : value
  end
end
