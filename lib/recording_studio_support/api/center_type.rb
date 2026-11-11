# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module CenterType
      module_function

      def register!
        RecordingStudioApi.register_recordable_type_api(
          CENTER_TYPE,
          api: Registration::OPERATIONS_API,
          writable_attributes: [],
          operations: %i[index show create]
        )
      end
    end
  end
end
