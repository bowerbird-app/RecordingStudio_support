# frozen_string_literal: true

require "test_helper"

class PagesTest < Minitest::Test
  def test_support_page_type_is_the_one_product_type
    assert_equal "RecordingStudioSupport::SupportPage", RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
    assert_equal "RecordingStudioSupport::SupportSection",
                 RecordingStudioSupport::Sections::SUPPORT_SECTION_TYPE
  end

  def test_pages_helpers_exist
    %i[for_root for_section find_for_root! find_kept! create! revise! trash! move! recording_for
       public_indexable public_for_section default_section_for section_for].each do |method_name|
      assert RecordingStudioSupport::Pages.respond_to?(method_name), "expected Pages.#{method_name}"
    end
  end

  def test_index_view_uses_flatpack_search
    index = File.read(File.expand_path("../app/views/recording_studio_support/sections/index.html.erb", __dir__))

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

  def test_section_and_page_lists_wrap_list_in_card
    staff_index = File.read(File.expand_path("../app/views/recording_studio_support/sections/index.html.erb", __dir__))
    public_index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )
    staff_show = File.read(File.expand_path("../app/views/recording_studio_support/sections/show.html.erb", __dir__))
    public_show = File.read(
      File.expand_path("../app/views/recording_studio_support/public_sections/show.html.erb", __dir__)
    )
    list = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_link_list.html.erb", __dir__)
    )

    [staff_index, public_index, staff_show, public_show].each do |view|
      assert_includes view, 'render "recording_studio_support/shared/link_list"'
      refute_includes view, "FlatPack::Card::Component"
      refute_includes view, 'text: "Read"'
      refute_includes view, 'text: "Open"'
    end

    assert_includes list, "FlatPack::Card::Component"
    assert_includes list, "card.body"
    assert_includes list, "FlatPack::List::Component"
    assert_includes list, "FlatPack::List::Item"
    assert_includes list, "support_list_chevron"
    refute_includes list, "card.header"
    refute_match(/List::Component\.new\([^)]*border:/, list)
    refute_includes list, 'text: "Read"'
    refute_includes list, 'text: "Open"'
  end

  def test_owner_preview_has_no_edit
    show = File.read(File.expand_path("../app/views/recording_studio_support/pages/show.html.erb", __dir__))

    refute_includes show, "edit_page_path"
    refute_includes show, 'text: "Edit"'
    assert_includes show, "Publish"
  end

  def test_public_index_uses_indexable_pages_not_copied_logic
    pages = File.read(File.expand_path("../lib/recording_studio_support/pages/lookups.rb", __dir__))
    public_index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )
    support_page = File.read(File.expand_path("../app/models/recording_studio_support/support_page.rb", __dir__))

    assert_includes pages, "SupportPage.indexable"
    assert_includes pages, "def public_indexable(query: nil)"
    assert_includes pages, "def public_for_section"
    assert_includes pages, ".distinct.order(:title)"
    refute_includes pages, "meta_robots"
    refute_includes pages, "noindex"
    assert_includes public_index, "FlatPack::Search::Component"
    assert_includes public_index, "max_width: :none"
    assert_includes public_index, "support_public_help_title"
    assert_includes public_index, 'render "recording_studio_support/shared/link_list"'
    refute_includes public_index, "FlatPack::Card::Component"
    refute_includes public_index, 'text: "Read"'
    refute_includes public_index, "recordable"
    assert_includes support_page, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes support_page, "RecordingStudio::Capabilities::Moveable.to"
  end

  def test_page_view_model_is_a_log_table
    source = File.read(File.expand_path("../app/models/recording_studio_support/page_view.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_page_views"'
    assert_includes source, "def self.record!"
    refute_includes source, "recording_studio_recordable"
  end
end
