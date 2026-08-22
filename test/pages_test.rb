# frozen_string_literal: true

require "test_helper"

class PagesTest < Minitest::Test
  def test_support_page_type_is_the_one_product_type
    assert_equal "RecordingStudioSupport::SupportPage", RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
  end

  def test_pages_helpers_exist
    %i[for_root find_for_root! find_kept! create! revise! trash! recording_for public_indexable
       allowed_parent_root? default_parent_root parent_root_for].each do |method_name|
      assert RecordingStudioSupport::Pages.respond_to?(method_name), "expected Pages.#{method_name}"
    end
  end

  def test_index_view_uses_flatpack_search
    index = File.read(File.expand_path("../app/views/recording_studio_support/pages/index.html.erb", __dir__))

    assert_includes index, "FlatPack::Search::Component"
    assert_includes index, 'name: "q"'
    assert_includes index, "max_width: :none"
    assert_includes index, 'class: "w-full"'
    assert_includes index, "support_help_title"
    assert_includes index, "support_help_subtitle"
    assert_includes index, "Nothing matches that"
    refute_includes index, "Elasticsearch"
    refute_includes index, "searchkick"
    refute_includes index, "SearchPage"
    refute_includes index, "New page"
    refute_includes index, "new_page_path"
  end

  def test_owner_preview_has_no_edit
    show = File.read(File.expand_path("../app/views/recording_studio_support/pages/show.html.erb", __dir__))

    refute_includes show, "edit_page_path"
    refute_includes show, 'text: "Edit"'
    assert_includes show, "Publish"
  end

  def test_public_index_uses_indexable_pages_not_copied_logic
    pages = File.read(File.expand_path("../lib/recording_studio_support/pages.rb", __dir__))
    public_index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )
    support_page = File.read(File.expand_path("../app/models/recording_studio_support/support_page.rb", __dir__))

    assert_includes pages, "SupportPage.indexable"
    assert_includes pages, "def public_indexable(query: nil)"
    assert_includes pages, ".distinct.order(:title)"
    refute_includes pages, "meta_robots"
    refute_includes pages, "noindex"
    assert_includes public_index, "FlatPack::Search::Component"
    assert_includes public_index, "max_width: :none"
    assert_includes public_index, "support_public_help_title"
    refute_includes public_index, "recordable"
    assert_includes support_page, "RecordingStudio::Capabilities::Publishable.to"
  end

  def test_page_view_model_is_a_log_table
    source = File.read(File.expand_path("../app/models/recording_studio_support/page_view.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_page_views"'
    assert_includes source, "def self.record!"
    refute_includes source, "recording_studio_recordable"
  end
end
