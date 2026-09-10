# frozen_string_literal: true

require "test_helper"

class SupportPageIconTest < Minitest::Test
  def test_page_form_accepts_heroicon_name
    form = File.read(File.expand_path("../app/views/recording_studio_support/pages/_form.html.erb", __dir__))
    controller = File.read(
      File.expand_path("../app/controllers/recording_studio_support/pages_controller.rb", __dir__)
    )
    pages = File.read(File.expand_path("../lib/recording_studio_support/pages.rb", __dir__))
    icon_field = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_icon_field.html.erb", __dir__)
    )

    assert_includes form, "recording_studio_support/shared/icon_field"
    assert_includes form, 'scope: "page"'
    assert_includes form, "Defaults to the section icon"
    assert_includes form, "recording-studio-support--icon-preview"
    assert_includes form, "support_section_icon_map"
    assert_includes icon_field, "name: input_name"
    assert_includes icon_field, "FlatPack::Shared::IconComponent"
    assert_includes controller, ":icon"
    assert_includes controller, "icon: page_params[:icon]"
    assert_includes controller, "apply_default_page_icon_from_section!"
    assert_includes pages, "icon: nil"
    assert_includes pages, "page.icon = icon"
  end

  def test_icon_preview_controller_supports_page_and_section_inputs
    preview = File.read(
      File.expand_path(
        "../app/javascript/recording_studio_support/controllers/icon_preview_controller.js",
        __dir__
      )
    )

    assert_includes preview, "inputName"
    assert_includes preview, "sectionIcons"
    assert_includes preview, "sectionChanged"
    assert_includes preview, "page[section_id]"
    assert_includes preview, "nameValue"
    assert_includes preview, "hasDrawnPaths"
    refute File.exist?(
      File.expand_path(
        "../app/javascript/recording_studio_support/controllers/section_icon_preview_controller.js",
        __dir__
      )
    )
  end
end
