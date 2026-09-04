# frozen_string_literal: true

require "test_helper"

class RecordingStudioSupportTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.7.2", ::RecordingStudioSupport::VERSION
  end

  def test_lockfiles_pin_this_gem_version
    version = ::RecordingStudioSupport::VERSION
    expected = "recording_studio_support (#{version})"

    assert_includes File.read(File.expand_path("../Gemfile.lock", __dir__)), expected
    assert_includes File.read(File.expand_path("dummy/Gemfile.lock", __dir__)), expected
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioSupport::Engine
  end

  def test_gemspec_pins_recording_studio_kit_and_support_mixins
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.6"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_admin", "~> 2.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", "~> 0.4"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_trashable", "~> 0.4"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_orderable", "~> 0.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_publishable", "~> 0.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_moveable", "~> 3.0"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.9.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_moveable", tag: "3.0.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_icons"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.151"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.6.1"'
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_does_not_ship_copied_core_hooks_or_template_leftovers
    refute File.exist?(File.expand_path("../lib/recording_studio_support/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_support/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_support/services/example_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_support/capabilities/example.rb", __dir__))
    refute File.exist?(File.expand_path("../app/controllers/recording_studio_support/home_controller.rb", __dir__))
    assert File.exist?(File.expand_path("../app/controllers/recording_studio_support/pages_controller.rb", __dir__))
    assert File.exist?(File.expand_path("../app/controllers/recording_studio_support/sections_controller.rb", __dir__))
    assert File.exist?(File.expand_path("../app/models/recording_studio_support/support_section.rb", __dir__))
  end

  def test_support_section_declares_product_label_and_host_root_parent
    source = File.read(File.expand_path("../app/models/recording_studio_support/support_section.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_sections"'
    assert_includes source, 'label: "Help section"'
    assert_includes source, "root: false"
    assert_includes source, 'allowed_parent_types: ["Workspace"]'
    assert_includes source, "RecordingStudio::Capabilities::Trashable.to"
    assert_includes source, "RecordingStudio::Capabilities::Orderable.to"
    assert_includes source, 'allows: ["RecordingStudioSupport::SupportPage"]'
    refute_includes source, "Capabilities::Attachable"
    refute_includes source, "Capabilities::Publishable"
    refute_includes source, "Capabilities::Moveable"
    refute_includes source, "Recordable"
    refute_match(/label:\s*"[^"]*Recordable/, source)
  end

  def test_support_page_declares_product_label_and_host_root_parent
    source = File.read(File.expand_path("../app/models/recording_studio_support/support_page.rb", __dir__))

    assert_includes source, 'self.table_name = "recording_studio_support_pages"'
    assert_includes source, 'label: "Support page"'
    assert_includes source, "root: false"
    assert_includes source, 'allowed_parent_types: ["RecordingStudioSupport::SupportSection"]'
    refute_includes source, "Capabilities::Attachable"
    assert_includes source, "RecordingStudio::Capabilities::Trashable.to"
    refute_includes source, "Capabilities::Orderable"
    assert_includes source, "RecordingStudio::Capabilities::Moveable.to"
    assert_includes source, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes source, "public_controller: \"recording_studio_support/public_pages\""
    assert_includes source, "public_action: :show"
    assert_includes source, "public_layout: \"recording_studio/default_layout\""
    assert_includes source, "path: \"/help/:uuid/:slug\""
    refute_includes source, 'allows: ["RecordingStudioAttachable::Attachment"]'
    refute_includes source, "Recordable"
    refute_match(/label:\s*"[^"]*Recordable/, source)
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "return \"application\" if devise_controller?"
    assert_includes controller_source, "recording_studio_user/auth"
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(
      File.expand_path("dummy/app/views/layouts/recording_studio/default_layout.html.erb", __dir__)
    )
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__))
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

  def test_dummy_uses_recording_studio_user_auth
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    initializer = File.read(File.expand_path("dummy/config/initializers/recording_studio_user.rb", __dir__))
    recording_studio = File.read(File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__))
    seeds = File.read(File.expand_path("dummy/db/seeds.rb", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))

    assert_includes routes, "skip: %i[sessions registrations passwords]"
    assert_includes routes, "recording_studio_user_auth_for :users"
    assert_includes routes, "mount RecordingStudioUser::Engine"
    assert_includes routes, "omniauth_callbacks: \"recording_studio_user/omniauth_callbacks\""
    assert_includes initializer, "config.otp_enabled = false"
    assert_includes initializer, 'config.layout = "recording_studio/default_layout"'
    assert_includes recording_studio, '"RecordingStudioUser::People"'
    assert_includes recording_studio, '"RecordingStudioUser::Profile"'
    assert_includes seeds, "RecordingStudioUser.create_user!"
    assert_includes seeds, "RecordingStudioUser.profile_for"
    assert_includes seeds, "admin@admin.com"
    refute_includes gemspec, "recording_studio_user"

    tailwind_sources = File.read(File.expand_path("dummy/config/initializers/tailwind_gem_sources.rb", __dir__))
    tailwind_css = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))
    assert_includes tailwind_sources, "recording_studio_user"
    assert_includes tailwind_css, "vendor/recording_studio_user/app/views"
  end

  def test_dummy_pins_turbo_and_loads_flatpack_js
    application_js = File.read(File.expand_path("dummy/app/javascript/application.js", __dir__))
    controllers_js = File.read(File.expand_path("dummy/app/javascript/controllers/index.js", __dir__))
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes application_js, 'import "@hotwired/turbo-rails"'
    assert_includes application_js, 'import "controllers"'
    refute_includes application_js, 'import { application } from "controllers/application"'
    assert_includes importmap, 'pin "@hotwired/turbo-rails", to: "turbo.min.js"'
    assert_includes importmap, "flat_pack/tiptap"
    assert_includes importmap, 'pin "controllers/flat_pack/tiptap_controller"'
    assert_includes importmap, 'pin "@tiptap/core"'
    assert_includes importmap, 'pin "@tiptap/starter-kit"'
    assert_includes controllers_js, "eagerLoadControllersFrom"
    assert_includes controllers_js, 'from "controllers/flat_pack/tiptap_controller"'
    assert_includes controllers_js, 'application.register("flat-pack--tiptap", TiptapController)'
  end

  def test_dummy_default_layout_head_loads_flatpack_and_root_switch_chrome
    head_path = File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    default_layout_head = File.read(head_path)

    assert_includes default_layout_head, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes default_layout_head, "start_with?"
    assert_includes default_layout_head, "recording_studio_root_switch_dropdown"
    assert_includes default_layout_head, "recording_studio_page_nav_right"
    assert_includes default_layout_head, "user_signed_in?"
    assert_includes default_layout_head, "RecordingStudioSupport::"
    assert_includes default_layout_head, "RecordingStudioAdmin::"
    assert_includes default_layout_head, "RecordingStudioMoveable::"
    assert_includes default_layout_head, "Sign out"
    assert_includes default_layout_head, "destroy_user_session_path"
    assert_includes default_layout_head, "turbo_method: :delete"
    refute_includes default_layout_head, "dummy_page_nav"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "flatpack-*/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "../../../vendor/bundle/**/recording_studio/app/views/**/*.erb"
    assert_includes tailwind_source, "recordingstudio-*/app/views/**/*.erb"
    assert_includes tailwind_source, "../../../vendor/flat_pack/app/components/**/*.rb"
    assert_includes tailwind_source, "RecordingStudio_users"
    assert_includes tailwind_source, "recording_studio_user"
    assert_includes tailwind_source, "home/*/.local/share/mise/installs/ruby"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_recording_studio_registers_support_page_with_strict_declarations
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, '"RecordingStudioSupport::SupportSection"'
    assert_includes initializer_source, '"RecordingStudioSupport::SupportPage"'
    assert_includes initializer_source, '"RecordingStudioUser::People"'
    assert_includes initializer_source, '"RecordingStudioUser::Profile"'
    assert_includes initializer_source, '"RecordingStudioAttachable::Attachment"'
    assert_includes initializer_source, '"RecordingStudioPublishable::Publishable"'
    assert_includes initializer_source, '"AdminRoot"'
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to prove Recording Studio Support"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "/support"
    assert_includes readme_source, "/help"
    assert_includes readme_source, "/admin"
    assert_includes readme_source, "redirects to `/`"
    assert_includes readme_source, "flat-pack--tiptap"
    assert_includes readme_source, "does not copy the layout"
    assert_includes readme_source, "Continue with email"
    assert_includes readme_source, "/users/sign_in/password"
    assert_includes readme_source, "recording_studio_user/auth"
    refute_includes readme_source, "flat_pack_sidebar"
    refute_includes readme_source, "/docs/"
  end

  def test_product_readme_is_the_support_guide
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "Recording Studio Support"
    assert_includes readme, "v4.2.0"
    assert_includes readme, "v0.9.1"
    assert_includes readme, "v0.1.151"
    assert_includes readme, "v0.9.0"
    assert_includes readme, "Support page"
    assert_includes readme, "SupportSection"
    assert_includes readme, "Help section"
    assert_includes readme, "Moveable"
    assert_includes readme, "tag: \"v2.0.2\""
    assert_includes readme, "/support"
    assert_includes readme, "help_title"
    assert_includes readme, "flat-pack--tiptap"
    assert_includes readme, "section :support"
    assert_includes readme, "recording_studio_user"
    assert_includes readme, "/users/sign_in/password"
    refute_includes readme, "RecordingStudio::Capabilities::Attachable.to"
    assert_includes readme, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes readme, "tag: \"v0.2.0\""
    assert_includes readme, "tag: \"v0.5.1\""
    assert_includes readme, "tag: \"0.2.0\""
    assert_includes readme, "/help"
    assert_includes readme, 'public_layout: "recording_studio/default_layout"'
    assert_includes readme, "config.help_title"
    refute_includes readme, 'public_layout: "recording_studio_publishable/application"'
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
    assert_includes view_source, "Open help pages"
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

  def test_engine_ships_authenticated_support_pages
    refute File.exist?(File.expand_path("../app/views/recording_studio_support/home/index.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/sections/index.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/pages/show.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/pages/new.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/pages/edit.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/public_pages/index.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/public_pages/show.html.erb", __dir__))
    assert File.exist?(File.expand_path("../app/views/recording_studio_support/public_sections/show.html.erb", __dir__))

    routes = File.read(File.expand_path("../config/routes.rb", __dir__))
    assert_includes routes, "RecordingStudioSupport::Engine.routes.draw"
    assert_includes routes, "resources :pages"
    assert_includes routes, "resources :sections"
    assert_includes routes, 'post "uploads"'
  end

  def test_dummy_defaults_to_studio_workspace_for_help_pages
    initializer = File.read(File.expand_path("dummy/config/initializers/recording_studio_root_switchable.rb", __dir__))

    assert_includes initializer, "Studio Workspace"
    assert_includes initializer, "default_root"
  end

  def test_engine_ships_admin_support_section
    admin = File.read(File.expand_path("../lib/recording_studio_support/admin.rb", __dir__))
    section = File.read(File.expand_path("../lib/recording_studio_support/admin/section.rb", __dir__))

    assert_includes admin, "RecordingStudioAdmin.register_section"
    assert_includes section, 'key "support"'
    assert_includes section, "configuration.admin_help_title"
    assert_includes section, "configuration.admin_help_subtitle"
    refute_includes section, "recordable"

    screen = File.read(File.expand_path("../lib/recording_studio_support/admin/pages_screen.rb", __dir__))
    sections_screen = File.read(File.expand_path("../lib/recording_studio_support/admin/sections_screen.rb", __dir__))
    assert_includes screen, 'key "support_pages"'
    assert_includes screen, "button :new_page"
    assert_includes screen, "action :edit"
    assert_includes screen, "column :status"
    refute_includes screen, "action :open"
    assert_includes sections_screen, "column :page_count"
    assert_includes sections_screen, 'title: "Count"'
    refute_includes sections_screen, "1 page"
    refute_includes sections_screen, "pages"
    assert_includes admin, "register_screen(SectionsScreen)"
    assert_includes admin, "register_widget(Widgets::PAGE_COUNT)"
  end

  def test_dummy_mounts_support_and_admin
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))

    assert_includes routes, 'mount RecordingStudioSupport::Engine, at: "/support"'
    assert_includes routes, "recording_studio_admin_for :admin, at: \"/admin\", root_section: :support"
    assert_includes routes, 'mount RecordingStudioAccessible::Engine, at: "/admin/access"'
    assert_includes routes, 'mount RecordingStudioPublishable::Engine, at: "/"'
    assert_includes routes, "RecordingStudioSupport::PublicPagesController.action(:index)"
    assert_includes routes, 'get "/help"'
    assert_includes routes, "PublicSectionsController"
    assert_includes routes, 'mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable"'
    assert_includes routes, "recording_studio_user_auth_for :users"
    assert_includes routes, "mount RecordingStudioUser::Engine"
  end

  def test_dummy_folder_and_page_do_not_opt_into_support_mixins
    folder_source = File.read(File.expand_path("dummy/app/models/folder.rb", __dir__))
    page_source = File.read(File.expand_path("dummy/app/models/page.rb", __dir__))

    refute_includes folder_source, "Capabilities::Attachable"
    refute_includes folder_source, "Capabilities::Trashable"
    refute_includes folder_source, "Capabilities::Orderable"
    refute_includes folder_source, "Capabilities::Publishable"
    refute_includes folder_source, "Capabilities::Moveable"
    refute_includes page_source, "Capabilities::Attachable"
    refute_includes page_source, "Capabilities::Trashable"
    refute_includes page_source, "Capabilities::Orderable"
    refute_includes page_source, "Capabilities::Publishable"
    refute_includes page_source, "Capabilities::Moveable"
  end
end
