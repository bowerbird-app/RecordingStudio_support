# frozen_string_literal: true

require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_trashable"
require "recording_studio_orderable"
require "recording_studio_admin"
require "recording_studio_support/version"
require "recording_studio_support/engine"
require "recording_studio_support/configuration"
require "recording_studio_support/pages"
require "recording_studio_support/admin"

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
