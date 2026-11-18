# frozen_string_literal: true

require "test_helper"

class SupportImportmapTest < ActiveSupport::TestCase
  # Importmap resolution does not read the database.
  self.use_transactional_tests = false
  fixtures []

  test "support controllers stay pinned and are not modulepreloaded" do
    importmap = Rails.application.importmap
    resolver = ApplicationController.helpers
    imports = JSON.parse(importmap.to_json(resolver: resolver)).fetch("imports")
    support_modules = imports.keys.grep(%r{\Acontrollers/recording_studio_support/})

    assert_includes support_modules, "controllers/recording_studio_support/icon_preview_controller"

    preloaded = importmap.preloaded_module_paths(resolver: resolver)
    preloaded_support = support_modules.select { |name| preloaded.include?(imports.fetch(name)) }

    assert_empty preloaded_support
  end
end
