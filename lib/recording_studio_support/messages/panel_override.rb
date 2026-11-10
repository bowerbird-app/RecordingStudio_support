# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    module PanelOverride
      def self.install!
        return unless defined?(ActionController::Base)

        path = RecordingStudioSupport::Engine.root.join("app/views/overrides").to_s
        paths = ActionController::Base.view_paths.map { |entry| entry.respond_to?(:to_path) ? entry.to_path : entry.to_s }
        return if paths.include?(path)

        ActionController::Base.prepend_view_path(path)
      end
    end
  end
end
