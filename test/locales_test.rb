# frozen_string_literal: true

require "test_helper"
require "yaml"
require_relative "../app/helpers/recording_studio_support/copy_helper"
require_relative "../app/helpers/recording_studio_support/public_section_helper"
require_relative "../app/helpers/recording_studio_support/list_helper"
require_relative "../app/helpers/recording_studio_support/body_helper"
require_relative "../app/helpers/recording_studio_support/application_helper"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioSupport::Copy

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "Hi, how can we help?", Copy.t("help.title")
      assert_equal "Search support", Copy.t("help.search_placeholder")
      assert_equal "Home", Copy.t("help.home")
      assert_equal "1 article", Copy.t("help.articles", count: 1)
      assert_equal "2 articles", Copy.t("help.articles", count: 2)
      assert_equal "Nothing matches that", Copy.t("empty.no_match_title")
      assert_equal "Try another word.", Copy.t("empty.no_match_description")
      assert_equal "Nothing live yet", Copy.t("empty.nothing_live_title")
      assert_equal "Check back soon.", Copy.t("empty.nothing_live_description")
      assert_equal "Updated August 21, 2026",
                   Copy.t("article.updated", date: Copy.l(Date.new(2026, 8, 21), format: :long))
      assert_equal "Find answers in Billing.", Copy.t("section.subtitle", title: "Billing")
      assert_equal "Search in Billing…", Copy.t("section.search_placeholder", title: "Billing")
      assert_equal "Contact support", Copy.t("contact.label")
      assert_equal "Need something else in Billing?", Copy.t("contact.prompt", title: "Billing")
      assert_equal "Try another keyword.", Copy.t("search.empty")
      assert_equal "Try another keyword or email us.",
                   Copy.t("search.empty_with_contact_html", contact: "email us")
      assert_equal "Messages", Copy.t("messages.title")
      assert_equal "Your notes to support, all in one place.", Copy.t("messages.subtitle")
      assert_equal "Someone", Copy.t("messages.someone")
    end
  end

  def test_ticket_desk_english_copy
    I18n.with_locale(:en) do
      assert_equal "New ticket", Copy.t("messages.new_ticket")
      assert_equal "No tickets yet", Copy.t("messages.empty_title")
      assert_equal "Sent. We’ll take a look.", Copy.t("messages.sent")
      assert_equal "Open", Copy.t("messages.statuses.open")
      assert_equal "Normal", Copy.t("messages.priorities.normal")
    end
  end

  def test_component_text_overrides_win_including_nil
    assert_equal "Hi, how can we help?", Copy.value(Copy::UNSET, "help.title")
    assert_equal "Acme help", Copy.value("Acme help", "help.title")
    assert_nil Copy.value(nil, "help.title")
  end

  def test_configured_defaults_follow_the_locale
    assert_equal "Hi, how can we help?",
                 Copy.defaulted("Hi, how can we help?", "Hi, how can we help?", "help.title")
    assert_equal "Guides", Copy.defaulted("Guides", "Hi, how can we help?", "help.title")
    assert_equal "Hi, how can we help?", Copy.defaulted(nil, "Hi, how can we help?", "help.title")
  end

  def test_host_translation_overrides_english
    I18n.backend.store_translations(:en, acme_title)
    assert_equal "Acme help", Copy.t("help.title")
  ensure
    I18n.backend.store_translations(:en, default_title)
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_public_helpers_still_honour_config_overrides
    helper = Object.new.extend(helper_module)
    section = Struct.new(:title, :slug).new("Billing", "billing")
    previous_title = RecordingStudioSupport.configuration.public_help_title
    previous_label = RecordingStudioSupport.configuration.public_contact_label
    previous_subtitle = RecordingStudioSupport.configuration.public_section_subtitle

    RecordingStudioSupport.configuration.public_help_title = "Acme help"
    RecordingStudioSupport.configuration.public_contact_label = "Email us"
    RecordingStudioSupport.configuration.public_section_subtitle = "Topic blurb."

    assert_equal "Acme help", helper.support_public_help_title
    assert_equal "Email us", helper.support_public_contact_label
    assert_equal "Topic blurb.", helper.support_public_section_subtitle(section)
  ensure
    RecordingStudioSupport.configuration.public_help_title = previous_title
    RecordingStudioSupport.configuration.public_contact_label = previous_label
    RecordingStudioSupport.configuration.public_section_subtitle = previous_subtitle
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("support")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  def acme_title
    { recording_studio: { support: { help: { title: "Acme help" } } } }
  end

  def default_title
    { recording_studio: { support: { help: { title: "Hi, how can we help?" } } } }
  end

  def helper_module
    Module.new do
      include ActionView::Helpers::OutputSafetyHelper
      include RecordingStudioSupport::ApplicationHelper
    end
  end
end
