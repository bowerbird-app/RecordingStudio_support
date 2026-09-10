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
       public_indexable public_for_section related_public_for kept_count_by_section public_count_by_section
       default_section_for section_for].each do |method_name|
      assert RecordingStudioSupport::Pages.respond_to?(method_name), "expected Pages.#{method_name}"
    end
  end

  def test_index_view_uses_flatpack_search
    index = File.read(File.expand_path("../app/views/recording_studio_support/sections/index.html.erb", __dir__))
    search = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_search.html.erb", __dir__)
    )
    public_index = File.read(
      File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__)
    )

    assert_includes index, 'render "recording_studio_support/shared/search"'
    assert_includes search, "FlatPack::Search::Component"
    assert_includes search, 'name: "q"'
    assert_includes search, 'local_assigns.fetch(:placeholder, "Search support")'
    assert_includes search, "max_width: :none"
    assert_includes search, 'class: "w-full"'
    assert_includes search, "--search-input-background-color: var(--color-white)"
    assert_includes search, "--search-input-border-color: var(--surface-border-color)"
    assert_includes search, "local_assigns.fetch(:size, :md)"
    assert_includes search, "size: size"
    refute_includes search, "prominent"
    refute_includes search, "[&_input]:py-3.5"
    assert_includes public_index, "size: :lg"
    assert_includes index, "Nothing matches that"
    refute_includes index, "Elasticsearch"
    refute_includes index, "searchkick"
    refute_includes index, "SearchPage"
    assert_includes index, "New page"
    assert_includes index, "new_page_path"
    assert_includes index, "New section"
    assert_includes index, "new_section_path"
    assert_includes index, "can_edit_support_pages?"
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

    assert_includes staff_index, "support_page_count_badge"
    refute_includes public_index, "support_page_count_badge"
    assert_includes public_index, "support_article_count_label"
    assert_includes public_index, "support_section_icon"
    assert_includes public_index, "support_section_icon_name"
    assert_includes public_index, "flex items-start gap-3"
    [staff_show, public_show].each do |show|
      refute_includes show, "support_page_count_badge"
    end
    refute_includes public_show, "support_published_badge"
    refute_includes staff_show, "support_published_badge"
    assert_includes staff_show, "support_page_status_badge"
    assert_includes staff_show, "can_edit_support_pages?"
    refute_includes staff_show, "current_support_actor.present?"

    [staff_index, staff_show].each do |view|
      assert_includes view, 'render "recording_studio_support/shared/link_list"'
      refute_includes view, "FlatPack::Card::Component"
      refute_includes view, 'text: "Read"'
      refute_includes view, 'text: "Open"'
    end

    refute_includes public_index, 'render "recording_studio_support/shared/link_list"'
    assert_includes public_index, "FlatPack::Grid::Component"
    assert_includes public_index, "FlatPack::Card::Component"
    assert_includes public_index, "style: :interactive"
    assert_includes public_index, "clickable: true"
    assert_includes public_index, "hover: :strong"
    assert_includes public_index, "padding: :lg"
    assert_includes public_index, "gap: :lg"
    assert_includes public_index, 'theme: { background: "#ffffff" }'
    assert_includes public_index, "card.body(padding: :lg)"
    refute_includes public_index, "style: :elevated"
    refute_includes public_index, "card.header"
    refute_includes public_index, "support_public_help_subtitle"
    refute_includes public_index, "square_rows"
    refute_includes public_index, 'text: "Read"'
    refute_includes public_index, 'text: "Open"'

    refute_includes public_show, "FlatPack::Breadcrumb::Component"
    assert_includes public_show, "support_public_section_page_nav"
    assert_includes public_show, "FlatPack::Grid::Component"
    assert_includes public_show, "FlatPack::Card::Component"
    assert_includes public_show, "FlatPack::Timestamp::Component"
    assert_includes public_show, "support_public_contact_href"
    assert_includes public_show, "size: :lg"
    assert_includes public_show, "hover: :strong"
    assert_includes public_show, "style: :interactive"
    assert_includes public_show, 'theme: { background: "var(--color-white)" }'
    assert_includes public_show, "gap: :lg"
    assert_includes public_show, "card.body(padding: :lg)"
    refute_includes public_show, "hover: :subtle"
    refute_includes public_show, "style: :elevated"
    refute_includes public_show, "gap: :sm"
    refute_includes public_show, 'render "recording_studio_support/shared/link_list"'
    refute_includes public_show, 'text: "Read"'
    refute_includes public_show, 'text: "Open"'
    refute_includes public_show, "page_nav_anchor_url"

    assert_includes list, "FlatPack::Card::Component"
    assert_includes list, "card.body"
    assert_includes list, "padding:"
    assert_includes list, "FlatPack::List::Component"
    assert_includes list, "FlatPack::List::Item"
    assert_includes list, "support_list_chevron"
    assert_includes list, "square_rows"
    assert_includes list, "[&>*]:rounded-none"
    refute_includes list, "card.header"
    refute_match(/List::Component\.new\([^)]*border:/, list)
    refute_includes list, 'text: "Read"'
    refute_includes list, 'text: "Open"'

    refute_includes staff_index, "square_rows"
  end

  def test_owner_preview_has_no_edit
    show = File.read(File.expand_path("../app/views/recording_studio_support/pages/show.html.erb", __dir__))

    refute_includes show, "edit_page_path"
    refute_includes show, 'text: "Edit"'
    assert_includes show, "Publish"
    assert_includes show, 'icon: "trash"'
    assert_includes show, "icon_only: true"
    refute_includes show, "View now"
    refute_includes show, "This page is live."
    refute_includes show, "FlatPack::Alert::Component"
    assert_includes show, 'text: live ? "Live" : "Draft"'
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
    assert_includes pages, "def related_public_for"
    assert_includes pages, ".distinct.order(:title)"
    refute_includes pages, "meta_robots"
    refute_includes pages, "noindex"
    assert_includes public_index, 'render "recording_studio_support/shared/search"'
    assert_includes public_index, "support_public_help_title"
    assert_includes public_index, "FlatPack::Card::Component"
    assert_includes public_index, "support_article_count_label"
    assert_includes public_index, "support_section_icon"
    refute_includes public_index, 'render "recording_studio_support/shared/link_list"'
    refute_includes public_index, 'text: "Read"'
    refute_includes public_index, "recordable"
    assert_includes support_page, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes support_page, "RecordingStudio::Capabilities::Moveable.to"
    refute_includes support_page, "Capabilities::Attachable"
    refute_includes support_page, "Capabilities::Orderable"
  end

  def test_public_show_is_a_simple_article
    show = File.read(File.expand_path("../app/views/recording_studio_support/public_pages/show.html.erb", __dir__))
    body_helper = File.read(
      File.expand_path("../app/helpers/recording_studio_support/body_helper.rb", __dir__)
    )

    assert_includes show, "FlatPack::Badge::Component"
    assert_includes show, "size: :lg"
    assert_includes show, 'class="w-fit"'
    assert_includes show, "FlatPack::PageTitle::Component"
    assert_includes show, "-mb-6"
    assert_includes show, "FlatPack::Timestamp::Component"
    assert_includes show, "timestamp: nil"
    assert_includes show, "support_page_updated_on"
    assert_includes show, "@page.description"
    assert_includes show, "support_page_body_class"
    assert_includes show, '"mt-8 mb-8 pb-8"'
    assert_includes show, "support_page_body_html"
    assert_includes show, "recording_studio_seo_description"
    assert_includes show, "support_page_meta_description"
    assert_includes show, "page_nav_secondary_anchor"
    assert_includes show, '"home"'
    assert_includes show, '"Home"'
    assert_includes show, "gap-1.5"
    refute_includes show, 'class: "text-sm text-[var(--surface-muted-content-color)]"'
    refute_includes show, "size: :sm"
    refute_includes show, "size: :md"
    refute_includes show, "Related"
    refute_includes show, 'render "recording_studio_support/shared/link_list"'
    refute_includes show, "FlatPack::SectionTitle::Component"
    refute_includes show, "page_nav_anchor_url"
    refute_includes show, "Pictures"
    refute_includes show, "This page is live"
    refute_includes show, "Not live yet"
    refute_includes show, "FlatPack::Alert::Component"
    refute_includes show, 'text: "Edit"'
    refute_includes show, "Move to trash"
    refute_includes show, "support_visible_images"
    refute_includes show, "FlatPack::Card::Component"

    assert_includes body_helper, "ARTICLE_BODY_CLASS"
    assert_includes body_helper, "flat-pack-content-editor-content"
    assert_includes body_helper, "support_page_body_class"
    assert_includes body_helper, "FlatPack::List::Component"
    assert_includes body_helper, "flat-pack-list-item-marker"
    assert_includes body_helper, 'ordered: node.name == "ol"'
    assert_includes body_helper, "spacing: :dense"
    assert_includes body_helper, "ARTICLE_LIST_ITEM_CLASS"
    refute_includes body_helper, "FlatPack::List::Item"
    assert_includes body_helper, "blockquote"
    assert_includes body_helper, 'class: "not-prose"'
    refute_includes body_helper, "surface-muted-content-color"
    refute_includes body_helper, "opacity-75"
    refute_includes body_helper, "prose max-w-none"
  end

  def test_page_form_uses_rich_text_uploads
    form = File.read(File.expand_path("../app/views/recording_studio_support/pages/_form.html.erb", __dir__))
    actions = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_form_actions.html.erb", __dir__)
    )

    assert_includes form, 'name: "page[description]"'
    assert_includes form, 'label: "Description"'
    assert_includes form, "recording_studio_support/shared/icon_field"
    assert_includes form, 'scope: "page"'
    assert_includes form, "FlatPack::Collapse::Component"
    assert_includes form, 'title: "Advanced settings"'
    assert_includes form, "border: false"
    assert_includes form, "preset: :content"
    assert_includes form, "uploads: { url: uploads_path }"
    assert_includes form, "image"
    refute_includes form, "uploads: false"
    assert_includes actions, 'text: "Save"'
    assert_includes actions, 'text: "Cancel"'
    refute_includes actions, "ButtonGroup"
    refute_includes actions, "w-full"
  end

  def test_section_form_accepts_heroicon_name
    form = File.read(File.expand_path("../app/views/recording_studio_support/sections/_form.html.erb", __dir__))
    controller = File.read(
      File.expand_path("../app/controllers/recording_studio_support/sections_controller.rb", __dir__)
    )
    sections = File.read(File.expand_path("../lib/recording_studio_support/sections.rb", __dir__))
    model = File.read(File.expand_path("../app/models/recording_studio_support/support_section.rb", __dir__))
    icon_field = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_icon_field.html.erb", __dir__)
    )

    assert_includes form, "recording_studio_support/shared/icon_field"
    assert_includes form, 'scope: "section"'
    assert_includes icon_field, ">Icon</label>"
    assert_includes icon_field, "items-start gap-3"
    assert_includes icon_field, "h-[calc(1.25rem+2*var(--form-control-padding)+2px)]"
    refute_includes icon_field, "h-11 w-11"
    assert_includes icon_field, "heroicons.com"
    assert_includes icon_field, "recording-studio-support--icon-preview"
    assert_includes icon_field, "FlatPack::Shared::IconComponent"
    refute_includes icon_field, 'label: "Icon"'
    refute_includes icon_field, "items-end"
    assert_includes controller, "permit(:title, :icon)"
    assert_includes controller, "icon: section_params[:icon]"
    assert_includes sections, "icon: nil"
    assert_includes model, "Concerns::HasHeroicon"

    preview = File.read(
      File.expand_path(
        "../app/javascript/recording_studio_support/controllers/icon_preview_controller.js",
        __dir__
      )
    )
    assert_includes preview, "nameValue"
    assert_includes preview, "normalize"
    assert_includes preview, "getControllerForElementAndIdentifier"
    assert_includes preview, "hasDrawnPaths"
    assert_includes preview, "Do not wipe those paths"
  end

  def test_page_view_model_is_a_log_table
    source = File.read(File.expand_path("../app/models/recording_studio_support/page_view.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_page_views"'
    assert_includes source, "def self.record!"
    refute_includes source, "recording_studio_recordable"
  end
end
