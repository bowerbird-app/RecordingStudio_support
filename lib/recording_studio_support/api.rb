# frozen_string_literal: true

require_relative "api/access"
require_relative "api/lookup"
require_relative "api/payload"
require_relative "api/serialize"
require_relative "api/center_type"
require_relative "api/registration"
require_relative "api/registration/handlers"
require_relative "api/idempotency"
require_relative "api/create"
require_relative "api/create_center"
require_relative "api/update"
require_relative "api/destroy"
require_relative "api/index"
require_relative "api/show"
require_relative "api/show_center"
require_relative "api/move"
require_relative "api/publishable_transition"
require_relative "api/refuse_public_sections"
require_relative "api/refuse_public_centers"

module RecordingStudioSupport
  module Api
    CENTER_TYPE = "RecordingStudioSupport::SupportCenter"
    SECTION_TYPE = "RecordingStudioSupport::SupportSection"
    PAGE_TYPE = "RecordingStudioSupport::SupportPage"
    TYPES = [SECTION_TYPE, PAGE_TYPE, CENTER_TYPE].freeze
    SUPPORT_OPENAPI = { tags: ["Support"], tag: { group: "Support" } }.freeze

    class << self
      def register!
        return unless recording_studio_api_available?

        Registration.register!
        register_openapi!(api: :public, types: [PAGE_TYPE])
        register_openapi!(api: Registration::OPERATIONS_API, types: [SECTION_TYPE, PAGE_TYPE, CENTER_TYPE])
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

      private

      def register_openapi!(api:, types:)
        types.each do |type|
          existing = RecordingStudioApi.recordable_registration_for(type, api: api)
          RecordingStudioApi.register_recordable_type_api(
            type,
            api: api,
            openapi: SUPPORT_OPENAPI,
            operations: existing&.operations
          )
        end
      end
    end
  end
end
