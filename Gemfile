# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_support.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.151"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", "~> 0.6", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"
gem "recording_studio_admin", "~> 2.0", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"
gem "recording_studio_attachable", "~> 0.4", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons"
gem "recording_studio_moveable", "~> 3.0", github: "bowerbird-app/RecordingStudio_moveable", tag: "3.0.0"
gem "recording_studio_orderable", "~> 0.2", github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"
gem "recording_studio_publishable", "~> 0.2", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.2.0"
gem "recording_studio_trashable", "~> 0.4", github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"

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
