# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module RefusePublicSections
      module_function

      def call(context)
        resource = if context.respond_to?(:resource_name) && context.resource_name.present?
                     context.resource_name
                   else
                     "support_sections"
                   end
        raise RecordingStudioApi::UnsupportedActionError,
              "#{resource} is not enabled on the public API"
      end
    end
  end
end
