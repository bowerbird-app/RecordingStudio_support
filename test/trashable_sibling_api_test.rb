# frozen_string_literal: true

require "test_helper"

class TrashableSiblingApiTest < Minitest::Test
  MAPPED_SOURCES = {
    "lib/recording_studio_support/pages/lookups.rb" => :active_scope,
    "lib/recording_studio_support/pages/counts.rb" => :active_scope,
    "lib/recording_studio_support/sections.rb" => :active_scope,
    "lib/recording_studio_support/sections/lookups.rb" => :active_scope,
    "lib/recording_studio_support/api/lookup.rb" => :active_scope,
    "lib/recording_studio_support/admin/queries.rb" => :active_scope,
    "app/models/recording_studio_support/support_section.rb" => :kept_sql
  }.freeze

  def test_mapped_call_sites_use_trashable_sibling_api
    MAPPED_SOURCES.each do |relative_path, kind|
      source = File.read(File.expand_path("../#{relative_path}", __dir__))

      refute_includes source, "trashed_at: nil",
                      "#{relative_path} still filters with trashed_at: nil"
      refute_match(/\.trashed_at\s+IS\s+NULL/i, source,
                   "#{relative_path} still embeds raw trashed_at IS NULL")

      case kind
      when :active_scope
        assert_includes source, "recording_studio_trashable_active",
                        "#{relative_path} should chain recording_studio_trashable_active"
      when :kept_sql
        assert_includes source, "recording_studio_trashable_kept_sql",
                        "#{relative_path} should use recording_studio_trashable_kept_sql"
      end
    end
  end

  def test_support_does_not_reimplement_void_or_predicates
    lib_and_app = Dir[
      File.expand_path("../lib/**/*.rb", __dir__),
      File.expand_path("../app/**/*.rb", __dir__)
    ]
    sources = lib_and_app.map { |path| File.read(path) }.join("\n")

    refute_match(/\bdef\s+void_recording!/, sources)
    refute_match(/\bdef\s+kept\?/, sources)
    refute_match(/\bdef\s+trashed\?/, sources)
    refute_match(/\bdef\s+kept_sql\b/, sources)
    refute_match(/\bdef\s+trashed_sql\b/, sources)
    refute_includes sources, "update_columns(trashed_at:"
  end

  def test_changelog_and_pins_document_trashable_0_9
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))

    assert_includes changelog, "## [0.17.0]"
    assert_includes changelog, "recording_studio_trashable_active"
    assert_includes changelog, "recording_studio_trashable_kept_sql"
    assert_includes changelog, "v0.9.0"
    assert_includes gemfile, 'tag: "v0.9.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_trashable", "~> 0.9"'
  end
end
