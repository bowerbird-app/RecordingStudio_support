# frozen_string_literal: true

require_relative "lib/recording_studio_support/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_support"
  spec.version     = RecordingStudioSupport::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_support"
  spec.summary     = "Self-serve support pages and a signed-in messages desk for Recording Studio hosts"
  spec.description = "Staff write help pages under a workspace. People help themselves at /help. " \
                     "Signed-in users and staff talk on a Messages desk under the support mount."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.9.1"
  spec.add_dependency "recording_studio_admin", "~> 2.0"
  spec.add_dependency "recording_studio_attachable", "~> 0.5.1"
  spec.add_dependency "recording_studio_messages", "~> 0.3.0"
  spec.add_dependency "recording_studio_moveable", "~> 3.0"
  spec.add_dependency "recording_studio_notifications", "~> 0.3.1"
  spec.add_dependency "recording_studio_notifications_email", "~> 0.3.1"
  spec.add_dependency "recording_studio_orderable", "~> 0.2"
  spec.add_dependency "recording_studio_publishable", "~> 0.3"
  spec.add_dependency "recording_studio_search", "~> 0.4"
  spec.add_dependency "recording_studio_trashable", "~> 0.4"
end
