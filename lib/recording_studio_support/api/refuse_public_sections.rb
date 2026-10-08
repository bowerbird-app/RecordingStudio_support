# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module RefusePublicSections
      module_function

      def call(_context)
        raise RecordingStudioApi::UnsupportedActionError,
              "support_sections is not enabled on the public API"
      end
    end
  end
end
