# frozen_string_literal: true

require "test_helper"

class SupportSectionIconTest < Minitest::Test
  def test_support_section_model_defines_icon_normalization
    source = File.read(
      File.expand_path("../app/models/recording_studio_support/support_section.rb", __dir__)
    )

    assert_includes source, "ICON_FORMAT"
    assert_includes source, "normalize_icon"
    assert_includes source, 'tr("_", "-")'
    assert_includes source, "allow_blank: true"
    assert_includes source, "Heroicons name"
  end

  def test_public_help_index_renders_section_icon_tiles
    index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )

    assert_includes index, "support_section_icon_name"
    assert_includes index, "support_section_icon"
    assert_includes index, "cols: 3"
    assert_includes index, "flex h-full flex-col gap-3"
    assert_includes index, "support_article_count_label"
  end
end
