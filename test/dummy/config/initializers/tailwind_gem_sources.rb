# frozen_string_literal: true

require "fileutils"

# Point Tailwind at the installed Flatpack and Recording Studio gems.
# The source globs also cover CI and mise paths; these links make local builds reliable.
if defined?(RecordingStudioRootSwitchable::TailwindSourceLinker)
  missing_link = %w[flat_pack recording_studio recording_studio_root_switchable].any? do |name|
    destination = Rails.root.join("vendor", name)
    !File.symlink?(destination) || !File.exist?(destination)
  end

  RecordingStudioRootSwitchable::TailwindSourceLinker.link!(rails_root: Rails.root) if missing_link
end

%w[
  recording_studio_admin
  recording_studio_support
  recording_studio_publishable
  recording_studio_user
].each do |gem_name|
  destination = Rails.root.join("vendor", gem_name)
  next if File.symlink?(destination) && File.exist?(destination)

  source = begin
    Bundler.load.specs.find { |spec| spec.name == gem_name }&.full_gem_path
  rescue StandardError
    nil
  end
  next if source.blank? || !Dir.exist?(source)

  FileUtils.mkdir_p(Rails.root.join("vendor"))
  FileUtils.rm_f(destination)
  File.symlink(source, destination)
end
