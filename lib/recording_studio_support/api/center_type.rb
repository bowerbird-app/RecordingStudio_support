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
        Registration.register_handler(CENTER_TYPE, :index, api: Registration::OPERATIONS_API, handler: Index)
        Registration.register_handler(CENTER_TYPE, :show, api: Registration::OPERATIONS_API, handler: ShowCenter)
      end
    end
  end
end
