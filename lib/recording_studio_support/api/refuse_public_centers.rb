# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module RefusePublicCenters
      module_function

      def call(_context)
        raise RecordingStudioApi::UnsupportedActionError,
              "support_centers is not enabled on the public API"
      end
    end
  end
end
