# frozen_string_literal: true

require "test_helper"

class PageNavCompatTest < Minitest::Test
  FakeNav = Class.new do
    attr_reader :kwargs

    def initialize(**kwargs)
      @kwargs = kwargs
    end
  end

  def setup
    @nav_class = Class.new(FakeNav)
    @nav_class.prepend(RecordingStudioSupport::PageNavCompat)
  end

  def test_maps_anchor_url_to_anchor_href
    nav = @nav_class.new(anchor_url: "/support", back_url: "/ignored", extra: true)

    assert_equal "/support", nav.kwargs[:anchor_href]
    refute nav.kwargs.key?(:anchor_url)
    refute nav.kwargs.key?(:back_url)
    assert_equal true, nav.kwargs[:extra]
  end
end
