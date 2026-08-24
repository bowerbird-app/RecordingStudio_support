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
       public_indexable public_for_section kept_count_by_section public_count_by_section
       default_section_for section_for].each do |method_name|
      assert RecordingStudioSupport::Pages.respond_to?(method_name), "expected Pages.#{method_name}"
    end
  end

  def test_index_view_uses_flatpack_search
    index = File.read(File.expand_path("../app/views/recording_studio_support/sections/index.html.erb", __dir__))
    search = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_search.html.erb", __dir__)
    )

    assert_includes index, 'render "recording_studio_support/shared/search"'
    assert_includes search, "FlatPack::Search::Component"
    assert_includes search, 'name: "q"'
    assert_includes search, 'placeholder: "Search support"'
    assert_includes search, "max_width: :none"
    assert_includes search, 'class: "w-full"'
    refute_includes search, "size:"
    refute_includes search, "fill:"
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

    [staff_index, public_index].each do |index|
      assert_includes index, "support_page_count_badge"
    end
    [staff_show, public_show].each do |show|
      refute_includes show, "support_page_count_badge"
      assert_includes show, "support_published_badge"
    end

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
    assert_includes public_index, 'render "recording_studio_support/shared/search"'
    assert_includes public_index, "support_public_help_title"
    assert_includes public_index, 'render "recording_studio_support/shared/link_list"'
    refute_includes public_index, "FlatPack::Card::Component"
    refute_includes public_index, 'text: "Read"'
    refute_includes public_index, "recordable"
    assert_includes support_page, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes support_page, "RecordingStudio::Capabilities::Moveable.to"
    refute_includes support_page, "Capabilities::Attachable"
    refute_includes support_page, "Capabilities::Orderable"
  end

  def test_public_show_is_a_simple_article
    show = File.read(File.expand_path("../app/views/recording_studio_support/public_pages/show.html.erb", __dir__))

    assert_includes show, "support_page_body_html"
    refute_includes show, "Pictures"
    refute_includes show, "This page is live"
    refute_includes show, "Not live yet"
    refute_includes show, "FlatPack::Alert::Component"
    refute_includes show, "FlatPack::Card::Component"
    refute_includes show, 'text: "Edit"'
    refute_includes show, "Move to trash"
    refute_includes show, "support_visible_images"
  end

  def test_page_form_uses_rich_text_uploads
    form = File.read(File.expand_path("../app/views/recording_studio_support/pages/_form.html.erb", __dir__))
    actions = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_form_actions.html.erb", __dir__)
    )

    assert_includes form, "preset: :content"
    assert_includes form, "uploads: { url: uploads_path }"
    assert_includes form, "image"
    refute_includes form, "uploads: false"
    assert_includes actions, 'text: "Save"'
    assert_includes actions, 'text: "Cancel"'
    refute_includes actions, "ButtonGroup"
    refute_includes actions, "w-full"
  end

  def test_page_view_model_is_a_log_table
    source = File.read(File.expand_path("../app/models/recording_studio_support/page_view.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_page_views"'
    assert_includes source, "def self.record!"
    refute_includes source, "recording_studio_recordable"
  end
end
