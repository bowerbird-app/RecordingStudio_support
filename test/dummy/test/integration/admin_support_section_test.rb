# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminSupportSectionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb")
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
    switch_to_admin_root!
  end

  test "admin support metric widgets read metrics and link to desk or pages" do
    patron = RecordingStudioUser.create_user!(
      email: "widget-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    RecordingStudioSupport::Tickets.open!(
      actor: patron,
      subject: "Widget queue #{SecureRandom.hex(4)}",
      body: "Need a person on this."
    )
    closed = RecordingStudioSupport::Tickets.open!(
      actor: patron,
      subject: "Closed for chart #{SecureRandom.hex(4)}",
      body: "Done."
    )
    closed.update!(status: :resolved)
    unassigned = RecordingStudioSupport::SupportTicket.open.where(assignee_id: nil).count
    assert_operator unassigned, :>=, 1

    get "/admin/sections/support/widgets/widgets.support.unassigned_open"

    assert_response :success
    assert_includes response.body, "Unassigned tickets"
    assert_includes response.body, unassigned.to_s
    assert_includes response.body, "/admin/screens/open_tickets?assignee=Unassigned"
    refute_includes response.body, "status=resolved"
    refute_includes response.body, "recordable"

    get "/admin/sections/support/widgets/widgets.support.oldest_open_age"

    assert_response :success
    assert_includes response.body, "Oldest open ticket"
    assert_includes response.body, "/admin/screens/open_tickets"
    refute_includes response.body, "/admin/support/messages"

    get "/admin/sections/support/widgets/widgets.support.avg_time_to_resolve"

    assert_response :success
    assert_includes response.body, "Time to close"
    assert_includes response.body, "/admin/screens/time_to_close"
    options = chart_options_from(response.body)
    assert_equal false, options.dig("xaxis", "labels", "show")
    assert_chart_xy_payload response.body

    get "/admin/sections/support/widgets/widgets.support.page_views"

    assert_response :success
    assert_includes response.body, "Help page views"
    assert_includes response.body, "/admin/screens/help_page_views"
    views_options = chart_options_from(response.body)
    assert_equal false, views_options.dig("xaxis", "labels", "show")
    assert_chart_xy_payload response.body, require_nonzero: true
  end

  test "open tickets screen lists oldest open tickets first" do
    patron = RecordingStudioUser.create_user!(
      email: "open-queue-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    older = travel_to(Time.utc(2026, 1, 2, 12)) do
      RecordingStudioSupport::Tickets.open!(
        actor: patron,
        subject: "Oldest waiting ticket",
        body: "Been here a while."
      )
    end
    newer = travel_to(Time.utc(2026, 3, 2, 12)) do
      RecordingStudioSupport::Tickets.open!(
        actor: patron,
        subject: "Newer open ticket",
        body: "Opened later."
      )
    end

    get "/admin/screens/open_tickets"

    assert_response :success
    assert_includes response.body, "Open tickets"
    refute_includes response.body, "recordable"

    get "/admin/screens/open_tickets/table"

    assert_response :success
    assert_includes response.body, older.subject
    assert_includes response.body, newer.subject
    assert_operator response.body.index(older.subject), :<, response.body.index(newer.subject)
    assert_includes response.body, RecordingStudioSupport::Admin::OpenTicketsScreen.desk_path(older)
    refute_includes response.body, "Table data"

    resolved = travel_to(Time.utc(2025, 12, 1, 12)) do
      ticket = RecordingStudioSupport::Tickets.open!(
        actor: patron,
        subject: "Already closed ticket",
        body: "This one is done."
      )
      ticket.update!(status: :resolved)
      ticket
    end

    get "/admin/screens/open_tickets/table"

    assert_response :success
    refute_includes response.body, resolved.subject

    get "/admin/screens/open_tickets/table", params: { assignee: "Unassigned" }

    assert_response :success
    assert_includes response.body, older.subject
  end

  test "time to close and help page views screens show a chart and table" do
    patron = RecordingStudioUser.create_user!(
      email: "close-queue-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    closed = RecordingStudioSupport::Tickets.open!(
      actor: patron,
      subject: "Closed waiting ticket",
      body: "Finished."
    )
    closed.update!(status: :resolved)

    get "/admin/screens/time_to_close"

    assert_response :success
    assert_includes response.body, "Time to close"
    refute_includes response.body, "recordable"

    get "/admin/screens/time_to_close/chart"

    assert_response :success
    assert_chart_xy_payload response.body

    get "/admin/screens/time_to_close/table"

    assert_response :success
    assert_includes response.body, closed.subject
    refute_includes response.body, "Table data"

    get "/admin/screens/help_page_views"

    assert_response :success
    assert_includes response.body, "Help page views"

    get "/admin/screens/help_page_views/chart"

    assert_response :success
    assert_chart_xy_payload response.body, require_nonzero: true

    get "/admin/screens/help_page_views/table"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "Table data"
  end

  test "time to close and help page views screens keep date range and group by inline" do
    get "/admin/screens/time_to_close"

    assert_response :success
    assert_inline_date_and_group_filters

    get "/admin/screens/help_page_views"

    assert_response :success
    assert_inline_date_and_group_filters
  end

  test "time to close filters bound the table and bucket the chart" do
    patron = RecordingStudioUser.create_user!(
      email: "close-filters-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    in_range = travel_to(Time.utc(2026, 10, 8, 12)) do
      ticket = RecordingStudioSupport::Tickets.open!(
        actor: patron,
        subject: "Closed this week",
        body: "In range."
      )
      ticket.update!(status: :resolved, resolved_at: Time.current)
      ticket
    end
    out_of_range = travel_to(Time.utc(2026, 8, 1, 12)) do
      ticket = RecordingStudioSupport::Tickets.open!(
        actor: patron,
        subject: "Closed last summer",
        body: "Out of range."
      )
      ticket.update!(status: :resolved, resolved_at: Time.current)
      ticket
    end
    later = travel_to(Time.utc(2026, 10, 10, 12)) do
      ticket = RecordingStudioSupport::Tickets.open!(
        actor: patron,
        subject: "Closed later this week",
        body: "Same week."
      )
      ticket.update!(status: :resolved, resolved_at: Time.current)
      ticket
    end

    table_params = { start_date: "2026-10-01", end_date: "2026-10-14" }
    get "/admin/screens/time_to_close/table", params: table_params

    assert_response :success
    assert_includes response.body, in_range.subject
    assert_includes response.body, later.subject
    refute_includes response.body, out_of_range.subject

    get "/admin/screens/time_to_close/chart", params: table_params.merge(group_by: "day")
    day_points = chart_x_labels(response.body)

    get "/admin/screens/time_to_close/chart", params: table_params.merge(group_by: "week")
    week_points = chart_x_labels(response.body)

    assert_operator day_points.size, :>, week_points.size
    assert_operator week_points.size, :>=, 1
  end

  test "help page views filters bound the table and bucket the chart" do
    workspace = Workspace.find_by!(name: "Studio Workspace")
    root = RecordingStudio.root_recording_for(workspace)
    section = seeded_section("Getting started")
    in_page = record_support_page(root, section, title: "Views this week #{SecureRandom.hex(4)}")
    out_page = record_support_page(root, section, title: "Views last summer #{SecureRandom.hex(4)}")
    later_page = record_support_page(root, section, title: "Views later this week #{SecureRandom.hex(4)}")
    travel_to(Time.utc(2026, 10, 8, 12)) do
      RecordingStudioSupport::PageView.create!(recording_id: in_page.id)
    end
    travel_to(Time.utc(2026, 8, 1, 12)) do
      RecordingStudioSupport::PageView.create!(recording_id: out_page.id)
    end
    travel_to(Time.utc(2026, 10, 10, 12)) do
      RecordingStudioSupport::PageView.create!(recording_id: later_page.id)
    end

    table_params = { start_date: "2026-10-01", end_date: "2026-10-14" }
    get "/admin/screens/help_page_views/table", params: table_params

    assert_response :success
    assert_includes response.body, in_page.recordable.title
    assert_includes response.body, later_page.recordable.title
    refute_includes response.body, out_page.recordable.title

    get "/admin/screens/help_page_views/chart", params: table_params.merge(group_by: "day")
    day_points = chart_x_labels(response.body)

    get "/admin/screens/help_page_views/chart", params: table_params.merge(group_by: "week")
    week_points = chart_x_labels(response.body)

    assert_operator day_points.size, :>, week_points.size
    assert_operator week_points.size, :>=, 1
  end

  test "admin support section shows a page count and two table links" do
    get "/admin"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_flatpack_rounded_theme
    assert_select "h1", text: "Support"
    refute_match(/>\s*Help\s*</, response.body)
    assert_includes response.body, "Support pages"
    assert_includes response.body, "Support sections"
    assert_includes response.body, "Open tickets"
    assert_includes response.body, "Time to close"
    assert_includes response.body, "Help page views"
    assert_includes response.body, "/admin/screens/support_pages"
    assert_includes response.body, "/admin/screens/support_sections"
    assert_includes response.body, "/admin/screens/open_tickets"
    assert_includes response.body, "/admin/screens/time_to_close"
    assert_includes response.body, "/admin/screens/help_page_views"
    assert_includes response.body, "Unassigned tickets"
    assert_includes response.body, "Oldest open ticket"
    assert_select "a[href='/admin/screens/support_pages'][data-fp-style='secondary']"
    refute_select "a[href='/admin/screens/support_pages'][data-fp-style='primary']"
    refute_includes response.body, "See every page"
    refute_includes response.body, "Latest pages"
    refute_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"
    refute_includes response.body, "Reads"
    refute_match(/>\s*Help pages\s*</, response.body)
    assert_includes response.body, "flat_pack/application"
    refute_includes response.body, "recordable"
  end

  test "admin support pages table lists draft and published pages" do
    get "/admin/screens/support_pages"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_flatpack_rounded_theme
    assert_includes response.body, "Support pages"
    assert_includes response.body, "New page"
    assert_includes response.body, "/admin/support/new"
    assert_includes response.body, 'name="search"'
    assert_includes response.body, 'name="status"'
    assert_includes response.body, 'name="section"'
    assert_includes response.body, "Published"
    assert_includes response.body, "Draft"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Studio Workspace"
    refute_includes response.body, "recordable"
    refute_includes response.body, "Table data"
    refute_includes response.body, "2 rows"
    refute_includes response.body, 'id="screen-table-count"'

    get "/admin/screens/support_pages/table"

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    assert_includes response.body, "Published"
    assert_includes response.body, "Draft"
    assert_includes response.body, "Edit"
    assert_includes response.body, "--table-border-color"
    assert_includes response.body, "<table"
    refute_includes response.body, "Table data"
    refute_includes response.body, "2 rows"
    refute_includes response.body, 'id="screen-table-count"'
    sign_in_edit = RecordingStudioSupport::Admin::Queries.edit_page_path(
      seeded_page("How do I sign in?")
    )
    password_edit = RecordingStudioSupport::Admin::Queries.edit_page_path(
      seeded_page("How do I change my password?")
    )
    assert_includes response.body, sign_in_edit
    assert_includes response.body, password_edit
  end

  test "admin support pages table filters by search and publish status" do
    get "/admin/screens/support_pages/table", params: { search: "change my password" }

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I sign in?"

    get "/admin/screens/support_pages/table", params: { search: "account settings" }

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I sign in?"

    get "/admin/screens/support_pages/table", params: { status: "Published" }

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    refute_includes response.body, "How do I change my password?"

    get "/admin/screens/support_pages/table", params: { status: "Draft" }

    assert_response :success
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I sign in?"

    get "/admin/screens/support_pages/table", params: { section: "Getting started" }

    assert_response :success
    assert_includes response.body, "How do I sign in?"
    assert_includes response.body, "How do I change my password?"
    refute_includes response.body, "How do I update payment details?"

    get "/admin/screens/support_pages/table", params: { section: "Billing" }

    assert_response :success
    assert_includes response.body, "How do I update payment details?"
    refute_includes response.body, "How do I sign in?"
  end

  test "admin support sections table lists sections" do
    get "/admin/screens/support_sections"

    assert_response :success
    assert_includes response.body, "Support sections"
    assert_includes response.body, "New section"
    assert_includes response.body, "/admin/support/sections/new"

    get "/admin/screens/support_sections/table"

    assert_response :success
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Billing"
    assert_includes response.body, "Developers"
    assert_includes response.body, "Count"
    assert_includes response.body, "Edit"
    assert_includes response.body, "<table"
    refute_includes response.body, "1 page"
    refute_includes response.body, "2 pages"
    refute_includes response.body, "1 pages"
    refute_includes response.body, "2 page"
    assert_equal(
      { "Billing" => "2", "Developers" => "1", "Getting started" => "2" },
      section_page_counts_from_table(response.body)
    )
    getting_started_edit = RecordingStudioSupport::Admin::Queries.edit_section_path(
      seeded_section("Getting started")
    )
    assert_includes response.body, getting_started_edit
  end

  test "edit is reachable from the admin table" do
    recording = seeded_page("How do I change my password?")

    get "/admin/screens/support_pages/table"

    assert_response :success
    assert_includes response.body, "/admin/support/#{recording.id}/edit"

    get "/admin/support/#{recording.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit page"
    assert_includes response.body, "flat-pack-richtext-wrapper"
    assert_includes response.body, "flat-pack--tiptap"
    assert_includes response.body, "Save"
    assert_includes response.body, "Cancel"
    assert_includes response.body, "/admin/screens/support_pages"
    assert_select "input[name='page[title]']"
  end

  test "section edit is reachable from the admin sections table" do
    section = seeded_section("Getting started")

    get "/admin/support/sections/#{section.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit section"
    assert_includes response.body, "Save"
    assert_includes response.body, "Cancel"
    assert_includes response.body, "/admin/screens/support_sections"
    assert_select "input[name='section[title]']"
    assert_select "input[name='section[icon]']"
    assert_includes response.body, "rocket-launch"
    assert_includes response.body, "recording-studio-support--icon-preview"
    assert_includes response.body, 'data-flat-pack--icon-name-value="rocket-launch"'
    refute_includes response.body, "flat-pack-button-group"
  end

  test "staff can update a section icon" do
    section = seeded_section("Billing")

    patch "/admin/support/sections/#{section.id}", params: {
      section: { title: "Billing", icon: "banknotes" }
    }

    assert_redirected_to "/admin/support/sections/#{section.id}"
    follow_redirect!
    assert_includes response.body, "Section updated."
    assert_equal "banknotes", section.reload.recordable.icon
  end

  test "admin support section hides host chrome and keeps access" do
    get "/admin"

    assert_response :success
    refute_includes response.body, "Sign out"
    refute_includes response.body, "/users/sign_out"
    refute_includes response.body, "Studio Workspace"
    assert_includes response.body, "Support pages"
    refute_includes response.body, "See every page"
    refute_includes response.body, "Open help pages"
  end

  test "admin support section is enabled on the dummy admin root" do
    assert_includes AdminRoot.recording_studio_admin_section_keys_for(nil, nil, nil), "support"
  end

  test "staff with admin root access can edit without a workspace grant" do
    staff = User.create!(
      email: "admin-editor-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    admin_root_recording = RecordingStudio.root_recording_for(AdminRoot.find_by!(name: "Admin"))
    grant_role!(admin_root_recording, staff, :admin)
    sign_in staff
    switch_to_admin_root!

    recording = seeded_page("How do I change my password?")
    get "/admin/support/#{recording.id}/edit"

    assert_response :success
    assert_includes response.body, "Edit page"
  end

  test "viewer without admin access is forbidden" do
    stranger = User.create!(
      email: "admin-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in stranger

    get "/admin"

    assert_response :forbidden
  end

  private

  def chart_options_from(html)
    document = Nokogiri::HTML(html)
    node = document.at_css("[data-flat-pack--chart-options-value]")
    assert node, "expected a Flatpack chart options payload"
    JSON.parse(node["data-flat-pack--chart-options-value"])
  end

  def assert_inline_date_and_group_filters
    assert_includes response.body, 'name="start_date"'
    assert_includes response.body, 'name="end_date"'
    assert_includes response.body, 'name="group_by"'
    assert_includes response.body, 'id="screen-filters-form"'
    assert_includes response.body, 'data-recording-studio-admin--screen-filters-modal-filters-value="false"'
    refute_includes response.body, 'id="screen-inline-filters-form"'
    refute_includes response.body, "FlatPack::ModalFilter"
  end

  def chart_x_labels(html)
    document = Nokogiri::HTML(html)
    node = document.at_css("[data-flat-pack--chart-series-value]")
    assert node, "expected a Flatpack chart series payload"
    series = JSON.parse(node["data-flat-pack--chart-series-value"])
    Array(series).flat_map do |row|
      Array(row["data"]).filter_map { |point| point.is_a?(Hash) ? point["x"] : nil }
    end.uniq
  end

  def assert_chart_xy_payload(html, require_nonzero: false)
    payload = CGI.unescapeHTML(html.to_s)
    assert_includes payload, '"x":'
    assert_includes payload, '"y":'
    refute_match(/"data":\[\["\d{4}-\d{2}-\d{2}"/, payload)
    refute_match(/"x":null/, payload)

    return unless require_nonzero

    document = Nokogiri::HTML(html)
    node = document.at_css("[data-flat-pack--chart-series-value]")
    assert node, "expected a Flatpack chart series payload"
    series = JSON.parse(node["data-flat-pack--chart-series-value"])
    ys = Array(series).flat_map { |row| Array(row["data"]).map { |point| point.is_a?(Hash) ? point["y"] : nil } }
    assert ys.any? { |value| value.to_f.positive? }, "expected a non-zero Help page views point, got #{series.inspect}"
  end

  def section_page_counts_from_table(html)
    document = Nokogiri::HTML(html)
    headers = document.css("thead th").map { |cell| cell.text.gsub(/\s+/, " ").strip }
    count_index = headers.index { |header| header == "Count" }
    raise "Count column missing from #{headers.inspect}" unless count_index

    document.css("tbody tr").each_with_object({}) do |row, counts|
      cells = row.css("td").map { |cell| cell.text.gsub(/\s+/, " ").strip }
      name = cells[0]
      next if name.blank?

      counts[name] = cells[count_index]
    end
  end

  def switch_to_admin_root!
    admin_root = AdminRoot.find_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: admin_root_recording.id,
        return_to: "/admin"
      }
    }
  end

  def grant_role!(recording, actor, role)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: actor
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
