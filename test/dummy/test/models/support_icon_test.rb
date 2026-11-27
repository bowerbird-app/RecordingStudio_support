# frozen_string_literal: true

require "test_helper"

class SupportIconTest < ActiveSupport::TestCase
  test "section and page reject an unknown icon and allow a blank one" do
    section = RecordingStudioSupport::SupportSection.new(title: "Icons", icon: "book")
    page = RecordingStudioSupport::SupportPage.new(title: "Icons", icon: "book")

    refute_predicate section, :valid?
    refute_predicate page, :valid?
    assert_includes section.errors[:icon].join, "book"
    assert_includes page.errors[:icon].join, "book"

    section.icon = ""
    page.icon = nil
    assert_predicate section, :valid?
    assert_predicate page, :valid?
  end

  test "section accepts a FlatPack heroicon and an alias FlatPack already maps" do
    section = RecordingStudioSupport::SupportSection.new(title: "Icons", icon: "book-open")
    aliased = RecordingStudioSupport::SupportSection.new(title: "Search", icon: "search")

    assert_predicate section, :valid?
    assert_predicate aliased, :valid?
    assert RecordingStudioSupport::Concerns::HasHeroicon.known_heroicon?("book-open")
    refute RecordingStudioSupport::Concerns::HasHeroicon.known_heroicon?("book")
  end
end
