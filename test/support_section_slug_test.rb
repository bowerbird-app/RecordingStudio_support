# frozen_string_literal: true

require "test_helper"

class SupportSectionSlugTest < Minitest::Test
  def test_staff_show_status_button_sits_between_publish_and_trash
    show = File.read(File.expand_path("../app/views/recording_studio_support/pages/show.html.erb", __dir__))

    assert_includes show, 'text: live ? "Live" : "Draft"'
    assert_includes show, "style: live ? :success : :secondary"
    refute_includes show, "This page is live."
    refute_includes show, "Not live yet"
    refute_includes show, "View now"
    refute_includes show, "FlatPack::Alert::Component"
    refute_includes show, "Open live page"
    assert_includes show, 'icon: "trash"'
    assert_includes show, "icon_only: true"
    assert_includes show, 'label: "Move to trash"'
  end

  def test_public_help_index_has_no_close_anchor
    index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )

    refute_includes index, "page_nav_anchor_url"
    refute_includes index, "Close"
  end

  def test_support_section_model_defines_slug_helpers
    source = File.read(File.expand_path("../app/models/recording_studio_support/support_section.rb", __dir__))

    assert_includes source, "def self.slug_for"
    assert_includes source, "RESERVED_SLUGS"
    assert_includes source, "before_validation :assign_slug_from_title"
    assert_includes source, "validates :slug, presence: true"
  end
end
