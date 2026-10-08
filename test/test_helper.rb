# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "active_record"
require "active_support/time"
require "i18n"
require "active_support/i18n"
Time.zone ||= "UTC"
require "recording_studio_support"

locale_file = File.expand_path("../config/locales/en.yml", __dir__)
I18n.load_path << locale_file unless I18n.load_path.include?(locale_file)
I18n.backend.load_translations
I18n.available_locales = Array(I18n.available_locales) | %i[en]
I18n.default_locale = :en
