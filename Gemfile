# frozen_string_literal: true

source "https://rubygems.org"

require_relative "test/support/widen_recording_studio_requirement"

# Specify your gem's dependencies in recording_studio_support.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
# Flatpack 0.1.329 is tag v0.1.329 (commit 3e49ad3). The gemspec floor stays >= 0.1.315.
gem "flat_pack", ">= 0.1.315", github: "bowerbird-app/flatpack", ref: "3e49ad38b1980add449194d27265edaa7b892c0d"
gem "recording_studio", ">= 6.1.0", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"
gem "recording_studio_accessible", "~> 0.11", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.19.1"
gem "recording_studio_admin", "~> 2.0", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.7.0"
gem "recording_studio_attachable", "~> 0.7", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.15.0"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.1.1"
gem "recording_studio_logs", ">= 0.4.0", "< 0.6", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.5.0"
# Commit pin until Messages ships a tag with the panel header hooks. Re-pin to that tag after it merges.
gem "recording_studio_messages", "~> 0.5",
    github: "bowerbird-app/RecordingStudio_messages", ref: "ef00cde8f0b875214e0c1ea2b8f99100614cd224"
gem "recording_studio_metrics", ">= 0.5.0", "< 0.6", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.5.0"
gem "recording_studio_moveable", "~> 3.2", github: "bowerbird-app/RecordingStudio_moveable", tag: "v3.4.3"
gem "recording_studio_notifications", ">= 0.3.1", "< 1",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.7.0"
gem "recording_studio_notifications_email", "~> 0.3.1",
    github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.3.4"
gem "recording_studio_orderable", "~> 0.2", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.4.0"
gem "recording_studio_publishable", "~> 0.4", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.12.0"
gem "recording_studio_search", "~> 0.6", github: "bowerbird-app/RecordingStudio_search", tag: "v0.6.0"
gem "recording_studio_trashable", "~> 0.9", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0"
gem "recording_studio_views", ">= 0.8.0", "< 0.9", github: "bowerbird-app/RecordingStudio_views", tag: "v0.8.0"
gem "view_component", "4.19.0"

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
