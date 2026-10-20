# frozen_string_literal: true

require "test_helper"

class AdminTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

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

  def test_section_links_to_the_admin_tables
    links = RecordingStudioSupport::Admin::Section.links
    names = links.map(&:name)
    texts = links.map(&:text)

    assert_includes names, :support_pages
    assert_includes names, :support_sections
    assert_includes names, :open_tickets
    assert_includes names, :time_to_close
    assert_includes names, :help_page_views
    assert_includes texts, "Support pages"
    assert_includes texts, "Support sections"
    assert_includes texts, "Open tickets"
    assert_includes texts, "Time to close"
    assert_includes texts, "Help page views"
    refute_includes names, :page_list
    refute_includes names, :open_pages
    refute_includes texts, "See every page"
    pages = links.find { |link| link.name == :support_pages }
    refute_equal :primary, pages.style
    assert_equal :secondary, pages.style
    links.each { |link| assert_equal :secondary, link.style }
  end

  def test_queries_build_authenticated_page_paths
    recording = Struct.new(:id).new("page-123")

    assert_equal "/admin/support/page-123", RecordingStudioSupport::Admin::Queries.page_path(recording)
    assert_equal "/admin/support/page-123/edit", RecordingStudioSupport::Admin::Queries.edit_page_path(recording)
    assert_equal "/admin/support/new", RecordingStudioSupport::Admin::Queries.new_page_path
    assert_equal "/admin", RecordingStudioSupport::Admin::Queries.admin_hub_path
    assert_equal "/admin/screens/support_pages", RecordingStudioSupport::Admin::Queries.admin_pages_screen_path
    assert_equal "/admin/screens/support_sections", RecordingStudioSupport::Admin::Queries.admin_sections_screen_path
    assert_equal "/admin/screens/open_tickets", RecordingStudioSupport::Admin::OpenTicketsScreen.path
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
    assert_includes called, RecordingStudioSupport::Admin::OpenTicketsScreen
    assert_includes called, RecordingStudioSupport::Admin::TimeToCloseScreen
    assert_includes called, RecordingStudioSupport::Admin::HelpPageViewsScreen
    RecordingStudioSupport::Admin::Widgets::ALL.each do |widget|
      assert_includes called, widget
    end
    refute defined?(RecordingStudioSupport::Admin::Widgets::SECTIONS)
    refute defined?(RecordingStudioSupport::Admin::Widgets::RECENT_PAGES)
    assert_equal 11, called.size
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
      assert_equal "Unassigned", unassigned.link_label
      assert_equal "/admin/screens/open_tickets?assignee=Unassigned", unassigned.link_to.call(context)
      assert_equal "1d 1h", oldest.value.call(context)
      assert_equal "Open tickets", oldest.link_label
      assert_equal "/admin/screens/open_tickets", oldest.link_to.call(context)
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
    series = [{ name: "Views", data: [{ x: "2026-10-01", y: 2 }] }]
    seen = []
    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |identifier, admin_context:, **params|
      seen << { identifier: identifier, context: admin_context, params: params }
      if identifier == "support_tickets.avg_time_to_resolve"
        [{ name: "Average time to resolve", data: [{ x: "2026-10-01", y: 12_000 }] }]
      else
        series
      end
    }) do
      resolve = RecordingStudioSupport::Admin::Widgets::AVG_TIME_TO_RESOLVE
      views = RecordingStudioSupport::Admin::Widgets::PAGE_VIEWS

      assert_equal :chart, resolve.type
      assert_equal :line, resolve.chart_type
      scaled = resolve.series.call(context)
      assert_time_to_close_xy_series(
        scaled,
        name: "Average time to resolve minutes",
        x_label: "2026-10-01",
        y_value: 200
      )
      assert_equal "/admin/screens/time_to_close", resolve.link_to.call(context)
      assert_equal "Time to close", resolve.link_label
      assert_equal false, resolve.chart_options.call(context).dig(:xaxis, :labels, :show)
      assert_equal series, views.series.call(context)
      assert_equal "/admin/screens/help_page_views", views.link_to.call(context)
      assert_equal "Help page views", views.link_label
    end

    assert_equal(
      %w[support_tickets.avg_time_to_resolve support_page_views.over_time],
      seen.map { |row| row[:identifier] }
    )
    seen.each do |row|
      assert_equal true, row[:params][:site_authorized]
    end
  end

  def test_open_tickets_screen_lists_oldest_first
    screen = RecordingStudioSupport::Admin::OpenTicketsScreen

    assert_equal "open_tickets", screen.key
    assert_equal "Open tickets", screen.title
    assert_equal :site, screen.blast_radius
    assert_equal :created_at, screen.table_value.default_sort_key
    assert_equal "asc", screen.table_value.default_direction
    assert_includes screen.table_value.columns.map(&:key), :waiting
    assert_includes screen.table_value.actions.map(&:name), :desk
    assert_includes screen.table_value.filters.map(&:key), :assignee
    assert_equal "/admin/screens/open_tickets?assignee=Unassigned", screen.unassigned_path
  end

  def test_time_to_close_and_help_page_views_screens
    close = RecordingStudioSupport::Admin::TimeToCloseScreen
    views = RecordingStudioSupport::Admin::HelpPageViewsScreen

    assert_equal "time_to_close", close.key
    assert_equal :site, close.blast_radius
    assert_equal :line, close.chart_value.type_value
    assert_equal :resolved_at, close.table_value.default_sort_key
    assert_equal "/admin/screens/time_to_close", close.path

    assert_equal "help_page_views", views.key
    assert_equal :site, views.blast_radius
    assert_equal :line, views.chart_value.type_value
    assert_equal :created_at, views.table_value.default_sort_key
    assert_equal "/admin/screens/help_page_views", views.path
  end

  def test_open_ticket_helpers_match_the_age_widget
    screen = RecordingStudioSupport::Admin::OpenTicketsScreen
    older = Struct.new(:created_at, :message_group_id).new(Time.utc(2026, 10, 17, 12), "group-old")
    newer = Struct.new(:created_at, :message_group_id).new(Time.utc(2026, 10, 19, 11), nil)

    travel_to Time.utc(2026, 10, 19, 12) do
      assert_equal "2d", screen.wait_label(older)
      assert_equal "1h", screen.wait_label(newer)
    end
    assert_equal "None", screen.wait_label(Struct.new(:created_at).new(nil))
    assert_equal "/admin/support/messages?group_id=group-old", screen.desk_path(older)
    assert_equal "/admin/support/messages", screen.desk_path(newer)
  end

  def test_duration_axis_uses_human_units_without_trailing_zeros
    axis = RecordingStudioSupport::Admin::DurationAxis
    context = Object.new

    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |_identifier, **|
      [{ name: "Average time to resolve", data: [{ x: "2026-10-01", y: 12_000.0 }] }]
    }) do
      scaled = axis.series("support_tickets.avg_time_to_resolve", context)
      assert_time_to_close_xy_series(
        scaled,
        name: "Average time to resolve minutes",
        x_label: "2026-10-01",
        y_value: 200
      )
    end

    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |_identifier, **|
      [{ name: "Average time to resolve", data: [{ x: "2026-10-01", y: 43_200 }] }]
    }) do
      scaled = axis.series("support_tickets.avg_time_to_resolve", context)
      assert_time_to_close_xy_series scaled, name: "Average time to resolve hours", x_label: "2026-10-01", y_value: 12
    end

    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |_identifier, **|
      [{ name: "Average time to resolve", data: [{ x: "2026-10-01", y: 345_600 }] }]
    }) do
      scaled = axis.series("support_tickets.avg_time_to_resolve", context)
      assert_time_to_close_xy_series scaled, name: "Average time to resolve days", x_label: "2026-10-01", y_value: 4
    end

    assert_equal 3.5, axis.axis_number(3.54)
    assert_equal 3, axis.axis_number(3.0)
  end

  def test_help_page_views_series_maps_date_value_and_date_keys
    context = Object.new
    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |_identifier, **|
      [{ name: "Support page views", data: [{ date: Date.new(2026, 10, 19), value: 55 }] }]
    }) do
      series = RecordingStudioSupport::Admin::Widgets::PAGE_VIEWS.series.call(context)
      point = series.first[:data].first

      assert_equal "Support page views", series.first[:name]
      assert_equal({ x: "2026-10-19", y: 55 }, point)
      assert_operator point[:y], :>, 0
    end

    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |_identifier, **|
      [{ name: "Support page views", data: [{ "date" => "2026-10-19", "value" => 55 }] }]
    }) do
      series = RecordingStudioSupport::Admin::HelpPageViewsScreen.chart_value.series.call(context)
      assert_equal 55, series.first[:data].first[:y]
      assert_equal "2026-10-19", series.first[:data].first[:x]
    end
  end

  def test_time_to_close_series_shape_is_xy_objects
    context = Object.new
    RecordingStudioMetrics::Admin.stub(:chart_series, lambda { |_identifier, **|
      [{ name: "Average time to resolve", data: [{ x: "2026-10-01", y: 12_000 }, { x: "2026-10-02", y: 6_000 }] }]
    }) do
      scaled = RecordingStudioSupport::Admin::Widgets::AVG_TIME_TO_RESOLVE.series.call(context)
      point = scaled.first[:data].first

      assert_kind_of Hash, point
      refute_kind_of Array, point
      assert_equal({ x: "2026-10-01", y: 200 }, point)
      scaled.first[:data].each do |item|
        assert_kind_of Hash, item
        assert item.key?(:x)
        assert item.key?(:y)
        refute_kind_of Array, item
      end
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

  def assert_time_to_close_xy_series(series, name:, x_label:, y_value:)
    assert_equal 1, series.size
    assert_equal name, series.first[:name]
    point = series.first[:data].first
    assert_kind_of Hash, point
    refute_kind_of Array, point
    assert_equal %i[x y], point.keys
    assert_kind_of String, point[:x]
    assert_kind_of Numeric, point[:y]
    refute point[:y].to_s.include?(".000000")
    assert_equal x_label, point[:x]
    assert_equal y_value, point[:y]
  end
end
