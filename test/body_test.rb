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

  def test_plain_text_strips_markup_and_unescapes_entities
    text = RecordingStudioSupport::Body.plain_text(
      "<p>Pay &amp; save &lt;today&gt;.</p><script>alert(1)</script>"
    )

    assert_equal "Pay & save <today>.", text
  end

  def test_meta_description_truncates_long_plain_text
    long = "a" * 200
    description = RecordingStudioSupport::Body.meta_description("<p>#{long}</p>")

    assert_equal 160, description.length
    assert description.end_with?("...")
  end

  def test_meta_description_is_blank_for_empty_body
    assert_nil RecordingStudioSupport::Body.meta_description("   ")
    assert_nil RecordingStudioSupport::Body.meta_description(nil)
  end
end
