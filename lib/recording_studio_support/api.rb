# frozen_string_literal: true

require_relative "api/access"
require_relative "api/lookup"
require_relative "api/payload"
require_relative "api/serialize"
require_relative "api/registration"
require_relative "api/create"
require_relative "api/update"
require_relative "api/destroy"
require_relative "api/index"
require_relative "api/show"
require_relative "api/move"
require_relative "api/publishable_transition"
require_relative "api/refuse_public_sections"

module RecordingStudioSupport
  module Api
    SECTION_TYPE = "RecordingStudioSupport::SupportSection"
    PAGE_TYPE = "RecordingStudioSupport::SupportPage"
    TYPES = [SECTION_TYPE, PAGE_TYPE].freeze

    class << self
      def register!
        return unless recording_studio_api_available?

        Registration.register!
        true
      end

      def support_type?(type)
        TYPES.include?(type.to_s)
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_recordable_type_api) &&
          RecordingStudioApi.respond_to?(:register_resource_handler)
      end
    end
  end
end
