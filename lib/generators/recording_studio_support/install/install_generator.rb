# frozen_string_literal: true

require "rails/generators"

module RecordingStudioSupport
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioSupport engine into your application"

      class_option(
        :mount_path,
        type: :string,
        default: "/support",
        desc: "Route prefix used when mounting the authenticated Support screens"
      )

      def mount_engine
        route %(mount RecordingStudioSupport::Engine, at: "#{options[:mount_path]}")
        route %(mount RecordingStudioPublishable::Engine, at: "/")
        route %(mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable")
        route %(get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help)
        route "get \"/help/sections/:id\", " \
              "to: RecordingStudioSupport::PublicSectionsController.action(:show), " \
              "as: :public_help_section"
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

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)

        tailwind_content = File.read(tailwind_css_path)
        missing_lines = missing_tailwind_source_lines(tailwind_content)

        if missing_lines.empty?
          say "Tailwind already configured to include RecordingStudioSupport and FlatPack sources.", :green
          return
        end

        if tailwind_content.include?('@import "tailwindcss"')
          inject_tailwind_sources(tailwind_css_path, missing_lines)
          return
        end

        show_manual_tailwind_notice(missing_lines)
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def show_missing_tailwind_notice
        say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
        say "If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow
        tailwind_source_lines.each do |line|
          say "  #{line}", :yellow
        end
      end

      def missing_tailwind_source_lines(tailwind_content)
        tailwind_source_lines.reject { |line| tailwind_content.include?(line) }
      end

      def inject_tailwind_sources(tailwind_css_path, missing_lines)
        inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
          "#{formatted_tailwind_source_block(missing_lines)}\n"
        end
        say "Added RecordingStudioSupport and FlatPack sources to Tailwind CSS configuration.", :green
        say "Run 'bin/rails tailwindcss:build' to rebuild your CSS.", :green
      end

      def formatted_tailwind_source_block(missing_lines)
        [
          "\n/* Include RecordingStudioSupport engine views for Tailwind CSS */",
          missing_lines.first(2),
          "\n/* Include FlatPack component sources for Tailwind CSS */",
          missing_lines.drop(2)
        ].flatten.reject(&:empty?).join("\n")
      end

      def show_manual_tailwind_notice(missing_lines)
        say "Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow
        say "Please manually add these lines to your Tailwind CSS config:", :yellow
        missing_lines.each do |line|
          say "  #{line}", :yellow
        end
      end

      def tailwind_source_lines
        [
          '@source "../../vendor/bundle/**/recording_studio_support/app/views/**/*.erb";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/' \
          'recording_studio_support-*/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
        ]
      end
    end
  end
end
