# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < Minitest::Test
  def test_support_page_updated_on_uses_the_publish_day
    helper = Object.new.extend(load_helper)

    assert_nil helper.support_page_updated_on(nil)
    assert_equal "Updated August 21, 2026", helper.support_page_updated_on(Time.utc(2026, 8, 21, 15, 30))
  end

  def test_support_page_meta_description_uses_plain_escaped_body_text
    helper = Object.new.extend(load_helper)

    assert_equal "Pay & save <today>.", helper.support_page_meta_description(
      "<p>Pay &amp; save &lt;today&gt;.</p>"
    )
    assert_nil helper.support_page_meta_description("")
  end

  def test_support_publish_path_is_blank_without_routes
    helper = Object.new.extend(load_helper)

    assert_nil helper.support_publish_path(nil)
    assert_nil helper.support_publish_path(Object.new)
  end

  def test_public_pages_controller_uses_default_layout
    source = File.read(
      File.expand_path("../app/controllers/recording_studio_support/public_pages_controller.rb", __dir__)
    )
    application = File.read(
      File.expand_path("../app/controllers/recording_studio_support/application_controller.rb", __dir__)
    )

    assert_includes application, "include RecordingStudio::UsesDefaultLayout"
    assert_includes source, "skip_before_action :authenticate_user!"
    refute_includes source, "recording_studio_publishable/application"
    refute_match(/^\s*layout\s/, source)
    assert_includes source, "Sections.public_index"
    assert_includes source, "@query = params[:q]"
    assert_includes source, "@publishable&.publish_at"
  end

  def test_sections_controller_requires_admin_for_staff_browse
    source = File.read(
      File.expand_path("../app/controllers/recording_studio_support/sections_controller.rb", __dir__)
    )
    index = File.read(
      File.expand_path("../app/views/recording_studio_support/sections/index.html.erb", __dir__)
    )

    refute_includes source, "skip_before_action :authenticate_user!"
    assert_includes source, "authorize_support!(:view)"
    assert_includes source, "redirect_to RecordingStudioSupport::Admin::Queries.admin_hub_path"
    refute_includes source, "Sections.public_index"
    refute_includes source, "support_section_index_recordings"
    assert_includes index, "can_edit_support_pages?"

    set_idx = source.index("before_action :set_section_recording")
    auth_idx = source.index("authorize_support!(:edit)")
    assert set_idx, "sections load before authorize"
    assert auth_idx, "sections authorize edit"
    assert set_idx < auth_idx, "section must load before authorize"
  end

  def test_pages_controller_loads_ownership_root_before_authorize
    source = File.read(
      File.expand_path("../app/controllers/recording_studio_support/pages_controller.rb", __dir__)
    )
    application = File.read(
      File.expand_path("../app/controllers/recording_studio_support/application_controller.rb", __dir__)
    )

    set_idx = source.index("before_action :set_page_recording")
    parent_idx = source.index("before_action :set_page_parent_section_for_authorization")
    view_idx = source.index("authorize_support!(:view)")
    edit_idx = source.index("authorize_support!(:edit)")

    assert set_idx < view_idx
    assert set_idx < edit_idx
    assert parent_idx < edit_idx
    assert_includes application, "admin_access_recording"
    refute_includes application, "content_root_for_authorization"
    refute_includes application, "recordings_for_support_authorization"
  end

  def test_support_recording_title_reads_the_page_title
    helper = Object.new.extend(load_helper)
    page = Struct.new(:title).new("Getting started")
    recording = Struct.new(:recordable).new(page)

    assert_equal "Getting started", helper.support_recording_title(recording)
    assert_nil helper.support_recording_title(nil)
  end

  def test_support_page_count_label_is_the_number
    helper = Object.new.extend(load_helper)

    assert_equal "0", helper.support_page_count_label(0)
    assert_equal "1", helper.support_page_count_label(1)
    assert_equal "2", helper.support_page_count_label(2)
  end

  def test_support_page_count_badge_uses_the_flatpack_badge
    source = File.read(
      File.expand_path("../app/helpers/recording_studio_support/list_helper.rb", __dir__)
    )

    assert_includes source, "def support_page_count_badge"
    assert_includes source, "FlatPack::Badge::Component"
    assert_includes source, "style: :default"
    assert_includes source, "size: :xs"
    refute_includes source, "removable: true"
    refute_includes source, "pluralize"
    refute_includes source, "def support_page_image_url"
    refute_includes source, "def support_visible_images"
  end

  def test_support_published_badge_uses_the_flatpack_badge
    source = File.read(
      File.expand_path("../app/helpers/recording_studio_support/list_helper.rb", __dir__)
    )

    assert_includes source, "def support_published_badge"
    assert_includes source, 'text: "Published"'
    assert_includes source, "style: :success"
    assert_includes source, "size: :xs"
    assert_includes source, "def support_page_status_badge"
    assert_includes source, 'text: "Draft"'
    assert_includes source, "size: :xs"
  end

  def test_support_list_chevron_uses_the_flatpack_icon
    source = File.read(
      File.expand_path("../app/helpers/recording_studio_support/list_helper.rb", __dir__)
    )

    assert_includes source, "def support_list_chevron"
    assert_includes source, "FlatPack::Shared::IconComponent"
    assert_includes source, '"chevron-right"'
  end

  def test_help_copy_helpers_read_configuration
    helper = Object.new.extend(load_helper)

    assert_equal "Help", helper.support_help_title
    assert_equal "Find an answer.", helper.support_help_subtitle
    assert_equal "Help", helper.support_public_help_title
    assert_equal "Find an answer.", helper.support_public_help_subtitle
    assert_equal "/help", helper.support_public_help_path
  end

  def test_public_section_helpers_cover_subtitle_search_and_contact
    helper = Object.new.extend(load_helper)
    section = Struct.new(:title, :slug).new("Billing", "billing")

    previous_subtitle = RecordingStudioSupport.configuration.public_section_subtitle
    previous_href = RecordingStudioSupport.configuration.public_contact_href
    previous_label = RecordingStudioSupport.configuration.public_contact_label

    RecordingStudioSupport.configuration.public_section_subtitle = nil
    RecordingStudioSupport.configuration.public_contact_href = nil
    RecordingStudioSupport.configuration.public_contact_label = "Contact support"

    assert_equal "Find answers in Billing.", helper.support_public_section_subtitle(section)
    assert_equal "Search in Billing…", helper.support_public_section_search_placeholder(section)
    assert_nil helper.support_public_contact_href
    assert_equal "Contact support", helper.support_public_contact_label
    assert_equal "Need something else in Billing?", helper.support_public_contact_prompt(section)

    RecordingStudioSupport.configuration.public_section_subtitle = lambda do |item|
      "Payments, invoices, and plan changes." if item.slug == "billing"
    end
    RecordingStudioSupport.configuration.public_contact_href = "mailto:help@example.com"
    RecordingStudioSupport.configuration.public_contact_label = "Email us"

    assert_equal "Payments, invoices, and plan changes.", helper.support_public_section_subtitle(section)
    assert_equal "mailto:help@example.com", helper.support_public_contact_href
    assert_equal "Email us", helper.support_public_contact_label
  ensure
    RecordingStudioSupport.configuration.public_section_subtitle = previous_subtitle
    RecordingStudioSupport.configuration.public_contact_href = previous_href
    RecordingStudioSupport.configuration.public_contact_label = previous_label
  end

  def test_support_page_snippet_uses_body_helper
    helper = Object.new.extend(load_helper)

    assert_equal "Pay & save <today>.", helper.support_page_snippet("<p>Pay &amp; save &lt;today&gt;.</p>")
    assert_nil helper.support_page_snippet("")
  end

  private

  def load_helper
    dir = File.expand_path("../app/helpers/recording_studio_support", __dir__)
    require File.join(dir, "public_section_helper.rb")
    require File.join(dir, "list_helper.rb")
    require File.join(dir, "application_helper.rb")
    RecordingStudioSupport::ApplicationHelper
  end
end
