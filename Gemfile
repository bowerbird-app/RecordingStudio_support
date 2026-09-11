# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_support.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.177"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"
gem "recording_studio_accessible", "~> 0.6", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"
gem "recording_studio_admin", "~> 2.0", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"
gem "recording_studio_attachable", "~> 0.4", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.1.1"
gem "recording_studio_moveable", "~> 3.0", github: "bowerbird-app/RecordingStudio_moveable", tag: "v3.0.1"
gem "recording_studio_orderable", "~> 0.2", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.2.2"
gem "recording_studio_publishable", "~> 0.2", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.2.1"
# Vendored while RecordingStudio_search is private (CI token cannot clone it).
# Upstream: ce6265e10a732cd40bd83a8dd9c5cfe710ca22f7 — switch back to github: once public.
gem "recording_studio_search", "~> 0.3", path: "vendor/recording_studio_search"
gem "recording_studio_trashable", "~> 0.4", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.4.1"

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
