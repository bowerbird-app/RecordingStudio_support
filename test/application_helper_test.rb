# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < Minitest::Test
  def test_support_page_updated_on_uses_the_publish_day
    helper = Object.new.extend(load_helper)

    assert_nil helper.support_page_updated_on(nil)
    assert_equal "Updated August 21, 2026", helper.support_page_updated_on(Time.utc(2026, 8, 21, 15, 30))
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
      File.expand_path("../app/helpers/recording_studio_support/application_helper.rb", __dir__)
    )

    assert_includes source, "def support_page_count_badge"
    assert_includes source, "FlatPack::Badge::Component"
    assert_includes source, "style: :default"
    assert_includes source, "size: :sm"
    refute_includes source, "removable: true"
    refute_includes source, "pluralize"
    refute_includes source, "def support_page_image_url"
    refute_includes source, "def support_visible_images"
  end

  def test_support_published_badge_uses_the_flatpack_badge
    source = File.read(
      File.expand_path("../app/helpers/recording_studio_support/application_helper.rb", __dir__)
    )

    assert_includes source, "def support_published_badge"
    assert_includes source, 'text: "Published"'
    assert_includes source, "style: :success"
    assert_includes source, "size: :sm"
  end

  def test_support_list_chevron_uses_the_flatpack_icon
    source = File.read(
      File.expand_path("../app/helpers/recording_studio_support/application_helper.rb", __dir__)
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

  private

  def load_helper
    path = File.expand_path("../app/helpers/recording_studio_support/application_helper.rb", __dir__)
    require path
    RecordingStudioSupport::ApplicationHelper
  end
end
