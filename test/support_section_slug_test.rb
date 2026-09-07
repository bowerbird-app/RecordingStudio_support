# frozen_string_literal: true

require "test_helper"

class SupportSectionSlugTest < Minitest::Test
  def test_slug_for_parameterizes_title
    assert_equal "getting-started", RecordingStudioSupport::SupportSection.slug_for("Getting started")
    assert_equal "section", RecordingStudioSupport::SupportSection.slug_for("!!!")
    assert_equal "section", RecordingStudioSupport::SupportSection.slug_for("sections")
  end

  def test_model_assigns_slug_before_validation
    section = RecordingStudioSupport::SupportSection.new(title: "Billing FAQ")

    assert section.valid?
    assert_equal "billing-faq", section.slug
  end

  def test_staff_show_alert_links_to_live_page
    show = File.read(File.expand_path("../app/views/recording_studio_support/pages/show.html.erb", __dir__))

    assert_includes show, "This page is live."
    assert_includes show, "View now"
    assert_includes show, "FlatPack::Link::Component"
    refute_includes show, "Open live page"
  end

  def test_public_help_index_has_no_close_anchor
    index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )

    refute_includes index, "page_nav_anchor_url"
    refute_includes index, "Close"
  end
end
