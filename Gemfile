# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_support.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
# Content + 18px reading type (Flatpack #215).
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.207"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.2"
gem "recording_studio_accessible", "~> 0.11", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.11.1"
gem "recording_studio_admin", "~> 2.0", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.6"
gem "recording_studio_attachable", "~> 0.7", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.7.1"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.1.1"
gem "recording_studio_messages", "~> 0.5", github: "bowerbird-app/RecordingStudio_messages", tag: "v0.5.2"
gem "recording_studio_moveable", "~> 3.0", github: "bowerbird-app/RecordingStudio_moveable", tag: "v3.0.3"
gem "recording_studio_notifications", ">= 0.3.1", "< 1",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.4.0"
gem "recording_studio_notifications_email", "~> 0.3.1",
    github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.3.4"
gem "recording_studio_orderable", "~> 0.2", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.2.5"
gem "recording_studio_publishable", "~> 0.4", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.4.2"
# Vendored while RecordingStudio_search is private (CI token cannot clone it).
# Upstream: d9cc54dd33ec625dd618f5520de56b9b49a29e01 — Search PR #2 Instant UI 0.4.0.
gem "recording_studio_search", "~> 0.4", path: "vendor/recording_studio_search"
gem "recording_studio_trashable", "~> 0.4", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.4.4"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
