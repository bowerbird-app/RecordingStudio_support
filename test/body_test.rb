# frozen_string_literal: true

require "test_helper"

class BodyTest < Minitest::Test
  def test_keeps_headings_and_lists_and_drops_images
    html = RecordingStudioSupport::Body.sanitize(
      "<h2>Next</h2><p>Ask a teammate.</p><ul><li>One</li></ul><img src=\"https://example.test/x.png\" alt=\"nope\">"
    )

    assert_includes html, "<h2>Next</h2>"
    assert_includes html, "<p>Ask a teammate.</p>"
    assert_includes html, "<li>One</li>"
    refute_includes html, "<img"
  end
end
