# frozen_string_literal: true

# Sibling gemspecs still require recording_studio below 5. No newer tag
# relaxes that. Rewrite the requirement when Bundler loads those gemspecs
# so this app can resolve 6.1.0. This file is not packaged in the gem.
module WidenRecordingStudioRequirement
  def add_dependency(name, *requirements)
    requirements = [">= 6.1.0"] if name.to_s == "recording_studio" && !allows_recording_studio_six?(requirements)

    super
  end

  private

  def allows_recording_studio_six?(requirements)
    Gem::Requirement.new(requirements).satisfied_by?(Gem::Version.new("6.1.0"))
  rescue ArgumentError
    false
  end
end

unless Gem::Specification.ancestors.include?(WidenRecordingStudioRequirement)
  Gem::Specification.prepend(WidenRecordingStudioRequirement)
end
