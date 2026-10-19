# frozen_string_literal: true

require "test_helper"

class AdminTest < Minitest::Test
  def test_support_section_is_help_not_jargon
    assert_equal "support", RecordingStudioSupport::Admin::Section.key
    assert_equal "Support", resolve_admin_copy(RecordingStudioSupport::Admin::Section.title)
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

    assert_equal "/admin/support/page-123", RecordingStudioSupport::Admin::Queries.page_path(recording)
    assert_equal "/admin/support/page-123/edit", RecordingStudioSupport::Admin::Queries.edit_page_path(recording)
    assert_equal "/admin/support/new", RecordingStudioSupport::Admin::Queries.new_page_path
    assert_equal "/admin", RecordingStudioSupport::Admin::Queries.admin_hub_path
    assert_equal "/admin/screens/support_pages", RecordingStudioSupport::Admin::Queries.admin_pages_screen_path
    assert_equal "/admin/screens/support_sections", RecordingStudioSupport::Admin::Queries.admin_sections_screen_path
    assert_equal "/admin/support/messages", RecordingStudioSupport::Admin::Queries.staff_messages_path
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
    RecordingStudioSupport::Admin::Widgets::ALL.each do |widget|
      assert_includes called, widget
    end
    refute defined?(RecordingStudioSupport::Admin::Widgets::SECTIONS)
    refute defined?(RecordingStudioSupport::Admin::Widgets::RECENT_PAGES)
    assert_equal 8, called.size
  end

  def test_section_includes_metric_widgets
    keys = RecordingStudioSupport::Admin::Section.widget_keys

    assert_includes keys, "widgets.support.page_count"
    assert_includes keys, "widgets.support.unassigned_open"
    assert_includes keys, "widgets.support.oldest_open_age"
    assert_includes keys, "widgets.support.avg_time_to_resolve"
    assert_includes keys, "widgets.support.page_views"
    assert_equal :site, RecordingStudioSupport::Admin::Section.blast_radius
  end

  def test_ticket_widgets_read_metrics_and_link_to_desk
    context = Object.new
    seen = []
    RecordingStudioMetrics::Admin.stub(:scalar_value, lambda { |identifier, admin_context:, **params|
      seen << { identifier: identifier, context: admin_context, params: params }
      identifier == "support_tickets.oldest_open_age" ? 90_000 : 4
    }) do
      unassigned = RecordingStudioSupport::Admin::Widgets::UNASSIGNED_OPEN
      oldest = RecordingStudioSupport::Admin::Widgets::OLDEST_OPEN_AGE

      assert_equal :number, unassigned.type
      assert_equal "Unassigned tickets", unassigned.title
      assert_equal 4, unassigned.value.call(context)
      assert_equal "Desk", unassigned.link_label
      assert_equal "/admin/support/messages", unassigned.link_to.call(context)
      assert_equal "1d 1h", oldest.value.call(context)
    end

    assert_equal(
      %w[support_tickets.unassigned_open support_tickets.oldest_open_age],
      seen.map { |row| row[:identifier] }
    )
    seen.each do |row|
      assert_same context, row[:context]
      assert_equal true, row[:params][:site_authorized]
      assert_equal :site, row[:params][:scope]
    end
  end

  def test_oldest_open_age_widget_shows_none_when_empty
    RecordingStudioMetrics::Admin.stub(:scalar_value, nil) do
      assert_equal "None", RecordingStudioSupport::Admin::Widgets::OLDEST_OPEN_AGE.value.call(Object.new)
    end
  end

  def test_chart_widgets_read_metrics_series
    context = Object.new
    series = [{ name: "Views", data: [["2026-10-01", 2]] }]
    seen = []
    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |identifier, admin_context:, **params|
      seen << { identifier: identifier, context: admin_context, params: params }
      series
    }) do
      resolve = RecordingStudioSupport::Admin::Widgets::AVG_TIME_TO_RESOLVE
      views = RecordingStudioSupport::Admin::Widgets::PAGE_VIEWS

      assert_equal :chart, resolve.type
      assert_equal :line, resolve.chart_type
      assert_equal series, resolve.series.call(context)
      assert_equal "/admin/support/messages", resolve.link_to.call(context)
      assert_equal series, views.series.call(context)
      assert_equal "/admin/screens/support_pages", views.link_to.call(context)
      assert_equal "Support pages", views.link_label
    end

    assert_equal(
      %w[support_tickets.avg_time_to_resolve support_page_views.over_time],
      seen.map { |row| row[:identifier] }
    )
    seen.each do |row|
      assert_equal true, row[:params][:site_authorized]
    end
  end

  def test_age_label_formats_waiting_time
    widgets = RecordingStudioSupport::Admin::Widgets

    assert_equal "None", widgets.age_label(nil)
    assert_equal "0s", widgets.age_label(0)
    assert_equal "45s", widgets.age_label(45)
    assert_equal "2h 3m", widgets.age_label((2 * 3_600) + (3 * 60))
    assert_equal "1d 1h", widgets.age_label(90_000)
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
