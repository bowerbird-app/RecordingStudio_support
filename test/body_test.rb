# frozen_string_literal: true

require "test_helper"

class BodyTest < Minitest::Test
  def test_keeps_headings_lists_and_inline_images
    html = RecordingStudioSupport::Body.sanitize(
      "<h2>Next</h2><p>Ask a teammate.</p><ul><li>One</li></ul>" \
      "<img src=\"/how-to-sign-in.jpg\" alt=\"Sign-in form\">" \
      "<script>alert(1)</script>"
    )

    assert_includes html, "<h2>Next</h2>"
    assert_includes html, "<p>Ask a teammate.</p>"
    assert_includes html, "<li>One</li>"
    assert_includes html, "<img src=\"/how-to-sign-in.jpg\" alt=\"Sign-in form\">"
    refute_includes html, "<script"
  end
end
