# frozen_string_literal: true

require "test_helper"

class PagesTest < Minitest::Test
  def test_support_page_type_is_the_one_product_type
    assert_equal "RecordingStudioSupport::SupportPage", RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
  end

  def test_pages_helpers_exist
    %i[for_root find_for_root! create! revise! trash! recording_for].each do |method_name|
      assert RecordingStudioSupport::Pages.respond_to?(method_name), "expected Pages.#{method_name}"
    end
  end

  def test_page_view_model_is_a_log_table
    source = File.read(File.expand_path("../app/models/recording_studio_support/page_view.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_page_views"'
    assert_includes source, "def self.record!"
    refute_includes source, "recording_studio_recordable"
  end
end
