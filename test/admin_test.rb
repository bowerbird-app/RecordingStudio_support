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

  def test_support_pages_screen_lists_pages
    assert_equal "support_pages", RecordingStudioSupport::Admin::PagesScreen.key
    assert_equal "Support pages", RecordingStudioSupport::Admin::PagesScreen.title
  end

  def test_support_sections_screen_lists_sections
    assert_equal "support_sections", RecordingStudioSupport::Admin::SectionsScreen.key
    assert_equal "Support sections", RecordingStudioSupport::Admin::SectionsScreen.title
  end

  def test_support_pages_screen_opens_edit_and_new
    table = RecordingStudioSupport::Admin::PagesScreen.table_value
    action_names = table.actions.map(&:name)
    column_keys = table.columns.map(&:key)
    buttons = RecordingStudioSupport::Admin::PagesScreen.buttons_value

    assert_includes action_names, :edit
    refute_includes action_names, :open
    assert_includes column_keys, :title
    assert_includes column_keys, :section
    assert_includes column_keys, :status
    assert_includes column_keys, :updated_at
    assert_equal :new_page, buttons.first.name
    assert_equal "New page", buttons.first.text
    refute table.show_table_heading?
    refute table.show_count?
    refute_equal "Table data", table.title
    filter_keys = table.filters.map(&:key)
    assert_includes filter_keys, :search
    assert_includes filter_keys, :status
    assert_includes filter_keys, :section
    status_filter = table.filters.find { |filter| filter.key == :status }
    assert_equal %w[Published Draft], status_filter.allowed_values
    assert_includes action_names, :move
  end

  def test_support_sections_screen_opens_edit_and_new
    table = RecordingStudioSupport::Admin::SectionsScreen.table_value
    action_names = table.actions.map(&:name)
    column_keys = table.columns.map(&:key)
    buttons = RecordingStudioSupport::Admin::SectionsScreen.buttons_value
    page_count = table.columns.find { |column| column.key == :page_count }

    assert_includes action_names, :edit
    refute_includes action_names, :open
    assert_includes column_keys, :title
    assert_includes column_keys, :page_count
    assert_includes column_keys, :updated_at
    assert_equal "Count", page_count.title
    refute page_count.sortable
    assert_equal :new_section, buttons.first.name
    assert_equal "New section", buttons.first.text
    refute table.show_table_heading?
    refute table.show_count?
  end

  def test_sections_page_count_column_is_the_number
    table = RecordingStudioSupport::Admin::SectionsScreen.table_value
    column = table.columns.find { |item| item.key == :page_count }
    row = Struct.new(:id).new("section-1")

    RecordingStudioSupport::Admin::Queries.stub(:section_page_count, 2) do
      assert_equal 2, column.cell(row, nil)
    end
  end

  def test_section_links_to_the_two_admin_tables
    links = RecordingStudioSupport::Admin::Section.links
    names = links.map(&:name)
    texts = links.map(&:text)

    assert_includes names, :support_pages
    assert_includes names, :support_sections
    assert_includes texts, "Support pages"
    assert_includes texts, "Support sections"
    refute_includes names, :page_list
    refute_includes names, :open_pages
    refute_includes texts, "See every page"
  end

  def test_queries_build_authenticated_page_paths
    recording = Struct.new(:id).new("page-123")

    assert_equal "/support/page-123", RecordingStudioSupport::Admin::Queries.page_path(recording)
    assert_equal "/support/page-123/edit", RecordingStudioSupport::Admin::Queries.edit_page_path(recording)
    assert_equal "/support/new", RecordingStudioSupport::Admin::Queries.new_page_path
    assert_equal "/admin/screens/support_pages", RecordingStudioSupport::Admin::Queries.admin_pages_screen_path
    assert_equal "/admin/screens/support_sections", RecordingStudioSupport::Admin::Queries.admin_sections_screen_path
  end

  def test_queries_label_published_and_draft_pages
    published = Object.new
    draft = Object.new
    published.define_singleton_method(:currently_published?) { true }
    draft.define_singleton_method(:currently_published?) { false }

    assert_equal "Published", RecordingStudioSupport::Admin::Queries.page_status(published)
    assert_equal "Draft", RecordingStudioSupport::Admin::Queries.page_status(draft)
    assert_equal :success, RecordingStudioSupport::Admin::Queries.page_status_badge_style("Published")
    assert_equal :info, RecordingStudioSupport::Admin::Queries.page_status_badge_style("Draft")
  end

  def test_queries_section_page_count_uses_kept_pages
    recording = Object.new
    relation = Minitest::Mock.new
    relation.expect(:count, 2)

    RecordingStudioSupport::Pages.stub(:kept_pages_for_section, lambda { |row|
      assert_same recording, row
      relation
    }) do
      assert_equal 2, RecordingStudioSupport::Admin::Queries.section_page_count(recording)
    end

    relation.verify
  end

  def test_queries_expose_table_search_and_status_filters
    queries = RecordingStudioSupport::Admin::Queries

    assert queries.respond_to?(:search_page_recordings)
    assert queries.respond_to?(:filter_page_recordings_by_status)
    assert queries.respond_to?(:filter_page_recordings_by_section)
    assert queries.respond_to?(:section_filter_options)
    assert queries.respond_to?(:move_page_path)
    assert queries.respond_to?(:search_section_recordings)
    assert queries.respond_to?(:section_page_count)
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
    assert_includes called, RecordingStudioSupport::Admin::SectionsScreen
    assert_includes called, RecordingStudioSupport::Admin::Widgets::PAGE_COUNT
    refute_includes called.map { |item| item.try(:key) }, "widgets.support.page_views"
    refute defined?(RecordingStudioSupport::Admin::Widgets::SECTIONS)
    refute defined?(RecordingStudioSupport::Admin::Widgets::RECENT_PAGES)
    assert_equal 4, called.size
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
