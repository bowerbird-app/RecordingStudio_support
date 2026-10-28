# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioSupport::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(
      pages_path: "/help",
      help_title: "Guides",
      help_subtitle: "Short answers.",
      admin_help_title: "Guides",
      admin_help_subtitle: "Staff view of those answers."
    )

    assert_equal "/help", @configuration.pages_path
    assert_equal "Guides", @configuration.help_title
    assert_equal "Short answers.", @configuration.help_subtitle
    assert_equal "Guides", @configuration.admin_help_title
    assert_equal "Staff view of those answers.", @configuration.admin_help_subtitle
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", pages_path: "/guides")

    refute_respond_to @configuration, :unknown_key
    refute_respond_to @configuration, :api_key
    refute_respond_to @configuration, :enable_feature_x
    refute_respond_to @configuration, :timeout
    assert_equal "/guides", @configuration.pages_path
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original, @configuration.to_h
  end

  def test_initialize_uses_defaults
    configuration = RecordingStudioSupport::Configuration.new

    assert_equal "/admin/support", configuration.pages_path
    assert_equal "/help", configuration.public_pages_path
    assert_equal "Help", configuration.help_title
    assert_equal "Find an answer.", configuration.help_subtitle
    assert_equal "Hi, how can we help?", configuration.public_help_title
    assert_equal "Find an answer.", configuration.public_help_subtitle
    assert_equal "Support", configuration.admin_help_title
    assert_equal "Pages people use when they get stuck.", configuration.admin_help_subtitle
    assert_nil configuration.public_section_subtitle
    assert_equal "/help/messages", configuration.public_contact_href
    assert_equal "Contact support", configuration.public_contact_label
    assert_nil configuration.messages_admin_email
    assert_nil configuration.messages_admin_finder
    assert_nil configuration.layout
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
    refute_includes configuration.to_h.keys, :api_key
    refute_includes configuration.to_h.keys, :timeout
    refute_includes configuration.to_h.keys, :enable_feature_x
  end

  def test_public_section_and_contact_config_merge
    @configuration.merge!(
      public_section_subtitle: "Topic blurb.",
      public_contact_href: "mailto:help@example.com",
      public_contact_label: "Email us"
    )

    assert_equal "Topic blurb.", @configuration.public_section_subtitle
    assert_equal "mailto:help@example.com", @configuration.public_contact_href
    assert_equal "Email us", @configuration.public_contact_label
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("pages_path" => "/docs", "help_title" => "Docs")

    assert_equal "/docs", @configuration.pages_path
    assert_equal "Docs", @configuration.help_title
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioSupport.configure

    assert_kind_of RecordingStudioSupport::Configuration, RecordingStudioSupport.configuration
  end
end
