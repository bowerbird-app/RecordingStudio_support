# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_support/version"
require "recording_studio_support/engine"
require "recording_studio_support/configuration"

module RecordingStudioSupport
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
