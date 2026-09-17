# frozen_string_literal: true

require_relative "api/access"
require_relative "api/payload"
require_relative "api/serialize"
require_relative "api/registration"
require_relative "api/create"
require_relative "api/update"
require_relative "api/destroy"
require_relative "api/index"
require_relative "api/show"
require_relative "api/move"
require_relative "api/intercept"
require_relative "api/controller_ext"

module RecordingStudioSupport
  module Api
    SECTION_TYPE = "RecordingStudioSupport::SupportSection"
    PAGE_TYPE = "RecordingStudioSupport::SupportPage"
    TYPES = [SECTION_TYPE, PAGE_TYPE].freeze

    class << self
      def register!
        return unless recording_studio_api_available?

        Registration.register!
        wrap_operations!
        wrap_controllers!
        true
      end

      def support_type?(type)
        TYPES.include?(type.to_s)
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_recordable_type_api)
      end

      private

      def wrap_operations!
        Intercept.operation_pairs.each { |klass, mod| wrap(klass, mod) }
        wrap_move_handlers!
      end

      def wrap_move_handlers!
        Intercept.move_classes.each { |klass| wrap(klass, Intercept::Move) }
      end

      def wrap_controllers!
        Intercept.controller_pairs.each { |klass, mod| wrap(klass, mod) }
      end

      def wrap(klass, mod)
        return if klass.nil?
        return if klass.ancestors.include?(mod)

        klass.prepend(mod)
      end
    end
  end
end
