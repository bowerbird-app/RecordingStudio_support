# frozen_string_literal: true

require "test_helper"

class PublicSectionTest < Minitest::Test
  def test_subtitle_default_and_callable_override
    section = Struct.new(:title, :slug).new("Billing", "billing")
    previous = RecordingStudioSupport.configuration.public_section_subtitle

    RecordingStudioSupport.configuration.public_section_subtitle = nil
    assert_equal "Find answers in Billing.", RecordingStudioSupport::PublicSection.subtitle_for(section)

    RecordingStudioSupport.configuration.public_section_subtitle = lambda do |item|
      "Payments, invoices, and plan changes." if item.slug == "billing"
    end
    assert_equal "Payments, invoices, and plan changes.",
                 RecordingStudioSupport::PublicSection.subtitle_for(section)
  ensure
    RecordingStudioSupport.configuration.public_section_subtitle = previous
  end

  def test_article_for_skips_pages_without_a_public_url
    page = Struct.new(:title, :body, :published_url, :created_at).new(
      "Draft only",
      "<p>Hidden</p>",
      nil,
      Time.utc(2026, 9, 1)
    )

    assert_nil RecordingStudioSupport::PublicSection.article_for(page)
  end

  def test_article_updated_at_prefers_publish_at_then_recording_then_created_at
    created = Time.utc(2026, 1, 1)
    recording_updated = Time.utc(2026, 2, 1)
    published = Time.utc(2026, 3, 1)

    page = Struct.new(:created_at).new(created)
    recording = Struct.new(:updated_at, :current_publishable).new(recording_updated, nil)

    RecordingStudioSupport::Pages.stub(:recording_for, recording) do
      assert_equal recording_updated, RecordingStudioSupport::PublicSection.article_updated_at(page)
    end

    publishable = Struct.new(:publish_at).new(published)
    recording_with_publish = Struct.new(:updated_at, :current_publishable).new(recording_updated, publishable)

    RecordingStudioSupport::Pages.stub(:recording_for, recording_with_publish) do
      assert_equal published, RecordingStudioSupport::PublicSection.article_updated_at(page)
    end

    RecordingStudioSupport::Pages.stub(:recording_for, nil) do
      assert_equal created, RecordingStudioSupport::PublicSection.article_updated_at(page)
    end
  end

  def test_article_for_includes_snippet_and_timestamp
    published = Time.utc(2026, 3, 1)
    page = Struct.new(:title, :body, :published_url, :created_at).new(
      "Where is my invoice?",
      "<p>Open Billing, then Invoices.</p>",
      "/help/abc/where-is-my-invoice",
      Time.utc(2026, 1, 1)
    )
    publishable = Struct.new(:publish_at).new(published)
    recording = Struct.new(:updated_at, :current_publishable).new(Time.utc(2026, 2, 1), publishable)

    article = RecordingStudioSupport::Pages.stub(:recording_for, recording) do
      RecordingStudioSupport::PublicSection.article_for(page)
    end

    assert_equal "Where is my invoice?", article.fetch(:title)
    assert_equal "/help/abc/where-is-my-invoice", article.fetch(:href)
    assert_equal "Open Billing, then Invoices.", article.fetch(:snippet)
    assert_equal published, article.fetch(:updated_at)
  end
end
