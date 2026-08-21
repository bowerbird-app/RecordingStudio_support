# frozen_string_literal: true

require "test_helper"

class RecordingStudioSupportTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.4.0", ::RecordingStudioSupport::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioSupport::Engine
  end

  def test_gemspec_pins_recording_studio_kit_and_support_mixins
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.6"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", "~> 0.4"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_trashable", "~> 0.4"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_orderable", "~> 0.2"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_publishable"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.133"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.6.0"'
    refute_includes gemfile, 'tag: "v0.1.134"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_does_not_ship_copied_core_hooks_or_template_leftovers
    refute File.exist?(File.expand_path("../lib/recording_studio_support/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_support/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_support/services/example_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_support/capabilities/example.rb", __dir__))
    refute File.exist?(File.expand_path("../app/controllers/recording_studio_support/home_controller.rb", __dir__))
  end

  def test_support_page_declares_product_label_and_host_root_parent
    source = File.read(File.expand_path("../app/models/recording_studio_support/support_page.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_pages"'
    assert_includes source, 'label: "Support page"'
    assert_includes source, "root: false"
    assert_includes source, 'allowed_parent_types: ["Workspace"]'
    assert_includes source, "RecordingStudio::Capabilities::Attachable.to"
    assert_includes source, "RecordingStudio::Capabilities::Trashable.to"
    assert_includes source, "RecordingStudio::Capabilities::Orderable.to"
    assert_includes source, 'allows: ["RecordingStudioAttachable::Attachment"]'
    refute_includes source, "Recordable"
    refute_match(/label:\s*"[^"]*Recordable/, source)
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "return \"application\" if devise_controller?"
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "FlatPack::Alert::Component"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_pins_turbo_and_loads_flatpack_js
    application_js = File.read(File.expand_path("dummy/app/javascript/application.js", __dir__))
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes application_js, 'import "@hotwired/turbo-rails"'
    refute_includes application_js, 'import { application } from "controllers/application"'
    assert_includes importmap, 'pin "@hotwired/turbo-rails", to: "turbo.min.js"'
  end

  def test_dummy_default_layout_head_loads_flatpack_and_root_switch_chrome
    default_layout_head = File.read(File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__))

    assert_includes default_layout_head, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes default_layout_head, "recording_studio_root_switch_dropdown"
    assert_includes default_layout_head, "recording_studio_page_nav_right"
    refute_includes default_layout_head, "Sign out"
    refute_includes default_layout_head, "dummy_page_nav"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "flatpack-*/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "../../../vendor/bundle/**/recording_studio/app/views/**/*.erb"
    assert_includes tailwind_source, "recordingstudio-*/app/views/**/*.erb"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_recording_studio_registers_support_page_with_strict_declarations
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, '"RecordingStudioSupport::SupportPage"'
    assert_includes initializer_source, '"RecordingStudioAttachable::Attachment"'
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to prove Recording Studio Support"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    refute_includes readme_source, "flat_pack_sidebar"
    refute_includes readme_source, "/docs/"
  end

  def test_product_readme_is_the_support_guide
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "Recording Studio Support"
    assert_includes readme, "v4.2.0"
    assert_includes readme, "v0.6.1"
    assert_includes readme, "v0.1.133"
    assert_includes readme, "Support page"
    assert_includes readme, "RecordingStudio::Capabilities::Attachable.to"
    assert_includes readme, "tag: \"0.4.0\""
    assert_includes readme, "tag: \"0.2.0\""
    refute_includes readme, "v3 declarations"
    refute_includes readme, "RecordingStudio v3"
    refute_includes readme, "ExampleService"
    refute_includes readme, "internal template"
    refute_includes readme, "recording_studio/v3.0.0"
  end

  def test_dummy_home_page_is_a_host_not_the_product
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Dummy host"'
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "recording_studio_page_nav"
    refute_includes view_source, "dummy_page_nav"
    refute_includes view_source, "Sign out"
    refute_includes view_source, "recording_studio_root_switch_dropdown"
    refute_includes view_source, "Template Demo"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_does_not_ship_starter_docs
    refute File.exist?(File.expand_path("dummy/app/controllers/docs_controller.rb", __dir__))
    assert_empty Dir[File.expand_path("dummy/app/views/docs/**/*.erb", __dir__)]
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_support/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end

  def test_dummy_folder_and_page_do_not_opt_into_support_mixins
    folder_source = File.read(File.expand_path("dummy/app/models/folder.rb", __dir__))
    page_source = File.read(File.expand_path("dummy/app/models/page.rb", __dir__))

    refute_includes folder_source, "Capabilities::Attachable"
    refute_includes folder_source, "Capabilities::Trashable"
    refute_includes folder_source, "Capabilities::Orderable"
    refute_includes page_source, "Capabilities::Attachable"
    refute_includes page_source, "Capabilities::Trashable"
    refute_includes page_source, "Capabilities::Orderable"
  end
end
