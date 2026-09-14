# frozen_string_literal: true

require "rails/generators"
require_relative "tailwind_sources"

module RecordingStudioSupport
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Install::TailwindSources

      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioSupport engine into your application"

      class_option(
        :mount_path,
        type: :string,
        default: "/admin/support",
        desc: "Route prefix used when mounting the staff Support screens"
      )

      def mount_engine
        route %(mount RecordingStudioSupport::Engine, at: "#{options[:mount_path]}")
        route %(get "/support", to: redirect("/admin"))
        route %(get "/support/*legacy_support_path", to: redirect("/admin"))
        route %(mount RecordingStudioPublishable::Engine, at: "/")
        route %(mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable")
        route %(get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help)
        route "get \"/help/sections/:slug\", " \
              "to: RecordingStudioSupport::PublicSectionsController.action(:show), " \
              "as: :public_help_section"
        instant = "RecordingStudioSupport::PublicInstantSearchesController.action(:show)"
        route "get \"/help/sections/:slug/instant_search\", to: #{instant}, as: :public_help_section_instant_search"
        route %(mount RecordingStudioSearch::Engine, at: "/recording_studio_search")
      end

      def copy_initializer
        template "recording_studio_support_initializer.rb", "config/initializers/recording_studio_support.rb"
      end

      def enable_admin_support_section
        admin_root_path = File.join(destination_root, "app/models/admin_root.rb")
        return unless File.exist?(admin_root_path)

        contents = File.read(admin_root_path)
        return if contents.include?("section :support")
        return unless contents.include?("recording_studio_admin_sections")

        inject_into_file "app/models/admin_root.rb", after: "recording_studio_admin_sections do\n" do
          "    section :support\n"
        end
      end

      def add_yaml_config
        prompt = "Would you like to add `config/recording_studio_support.yml` " \
                 "for environment-specific settings? [y/N]"
        return unless yes?(prompt)

        template "recording_studio_support.yml", "config/recording_studio_support.yml"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
