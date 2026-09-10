# frozen_string_literal: true

module RecordingStudioSupport
  class Engine < ::Rails::Engine
    initializer "recording_studio_support.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    initializer "recording_studio_support.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
    end
  end
end
