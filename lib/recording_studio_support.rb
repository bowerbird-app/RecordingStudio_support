# frozen_string_literal: true

require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_trashable"
require "recording_studio_orderable"
require "recording_studio_publishable"
require "recording_studio_moveable"
require "recording_studio_search"
require "recording_studio_admin"
require "recording_studio_notifications"
require "recording_studio_notifications_email"
require "recording_studio_messages"
require "recording_studio_support/version"
require "recording_studio_support/engine"
require "recording_studio_support/configuration"
require "recording_studio_support/pages"
require "recording_studio_support/sections"
require "recording_studio_support/messages"
require "recording_studio_support/tickets"
require "recording_studio_support/admin"
require "recording_studio_support/api"
require "recording_studio_support/page_nav_compat"
require "recording_studio_support/body"
require "recording_studio_support/public_section"
require "recording_studio_support/instant_pages"
require "recording_studio_support/search_instant_live_pages"

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
