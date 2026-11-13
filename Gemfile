# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_support.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", ">= 0.1.331", "< 1.0", github: "bowerbird-app/flatpack", tag: "v0.1.357"
gem "recording_studio", "~> 6.0", ">= 6.1.0", github: "bowerbird-app/RecordingStudio", tag: "v6.7.0"
gem "recording_studio_accessible", ">= 0.24", "< 1.0",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.32.0"
gem "recording_studio_admin", ">= 2.0", "< 3.0", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.13.0"
gem "recording_studio_attachable", ">= 0.7", "< 1.0", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.23.0"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.1"
gem "recording_studio_logs", ">= 0.4.0", "< 1.0", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.4"
gem "recording_studio_messages", ">= 0.17.0", "< 1.0", github: "bowerbird-app/RecordingStudio_messages", tag: "v0.25.1"
gem "recording_studio_metrics", ">= 0.5.0", "< 1.0", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.8.0"
gem "recording_studio_moveable", ">= 3.2", "< 5.0", github: "bowerbird-app/RecordingStudio_moveable", tag: "v4.1.1"
gem "recording_studio_notifications", ">= 0.3.1", "< 1.0",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.15.0"
gem "recording_studio_notifications_email", ">= 0.3.1", "< 1.0",
    github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.5.2"
gem "recording_studio_orderable", ">= 0.2", "< 1.0", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.7.0"
gem "recording_studio_publishable", ">= 0.4", "< 1.0",
    github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.15.0"
gem "recording_studio_search", ">= 0.6", "< 1.0", github: "bowerbird-app/RecordingStudio_search", tag: "v0.10.0"
gem "recording_studio_trashable", ">= 0.9", "< 1.0", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.14.0"
gem "recording_studio_views", ">= 0.8.0", "< 1.0", github: "bowerbird-app/RecordingStudio_views", tag: "v0.13.0"
# Attachable 0.23 and Publishable 0.15 depend on API. Not a Support gemspec dependency.
gem "recording_studio_api", ">= 0.23.0", "< 1.0", github: "bowerbird-app/RecordingStudio_api", tag: "v0.23.1"
gem "view_component", "4.19.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest", "~> 5.26"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
