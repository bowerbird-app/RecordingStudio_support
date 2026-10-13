# frozen_string_literal: true

require "test_helper"

class TrashableSiblingApiTest < Minitest::Test
  # Hash-filter sites keep main's additive trashed_at: nil because
  # recording_studio_trashable_active unscopes trashed_at first.
  HASH_FILTER_SOURCES = %w[
    lib/recording_studio_support/pages/lookups.rb
    lib/recording_studio_support/pages/counts.rb
    lib/recording_studio_support/sections.rb
    lib/recording_studio_support/sections/lookups.rb
    lib/recording_studio_support/api/lookup.rb
    lib/recording_studio_support/admin/queries.rb
  ].freeze

  def test_hash_filter_sites_keep_main_additive_trashed_at_nil
    HASH_FILTER_SOURCES.each do |relative_path|
      source = File.read(File.expand_path("../#{relative_path}", __dir__))
      code = source.lines.grep_v(/^\s*#/).join

      assert_includes code, "trashed_at: nil",
                      "#{relative_path} should keep main's additive trashed_at: nil"
      refute_includes code, "recording_studio_trashable_active",
                      "#{relative_path} must not chain trashable_active (unscope differs under default_scope)"
    end
  end

  def test_section_slug_join_uses_kept_sql
    source = File.read(
      File.expand_path("../app/models/recording_studio_support/support_section.rb", __dir__)
    )

    assert_includes source, "recording_studio_trashable_kept_sql"
    refute_match(/\.trashed_at\s+IS\s+NULL/i, source)
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
    assert_includes changelog, "recording_studio_trashable_kept_sql"
    assert_includes changelog, "recording_studio_trashable_active"
    assert_includes changelog, "v0.9.0"
    assert_includes gemfile, 'tag: "v0.9.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_trashable", "~> 0.9"'
  end
end
