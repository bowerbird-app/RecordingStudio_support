# frozen_string_literal: true

require "test_helper"

class InstantPagesTest < Minitest::Test
  def test_instant_pages_allowlists_support_page_only
    assert_equal "RecordingStudioSupport::SupportPage", RecordingStudioSupport::InstantPages::MODEL_NAME
    assert_equal "support_page_search_results", RecordingStudioSupport::InstantPages::FRAME_ID
  end

  def test_page_search_partial_uses_search_instant_field
    search = File.read(
      File.expand_path("../app/views/recording_studio_support/shared/_page_search.html.erb", __dir__)
    )

    assert_includes search, "instant_search_field"
    assert_includes search, "RecordingStudioSupport::InstantPages::MODEL_NAME"
    assert_includes search, "RecordingStudioSupport::InstantPages::FRAME_ID"
    assert_includes search, "support_search_routes"
    assert_includes search, 'role: "search"'
    refute_includes search, "pgvector"
    refute_includes search, "embedding"
  end

  def test_engine_and_install_mount_instant_routes
    routes = File.read(File.expand_path("../config/routes.rb", __dir__))
    install = File.read(
      File.expand_path("../lib/generators/recording_studio_support/install/install_generator.rb", __dir__)
    )
    initializer = File.read(
      File.expand_path("dummy/config/initializers/recording_studio_search.rb", __dir__)
    )

    assert_includes routes, "instant_searches#show"
    assert_includes install, "PublicInstantSearchesController"
    assert_includes install, 'mount RecordingStudioSearch::Engine, at: "/recording_studio_search"'
    assert_includes initializer, 'config.instant_search_models = ["RecordingStudioSupport::SupportPage"]'
    refute_includes initializer, "User"
    refute_includes initializer, "SupportSection"
  end
end
