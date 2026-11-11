# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Registration
      module Handlers
        module_function

        def register_reads!
          register_handler(PAGE_TYPE, :index, api: :public, handler: Index)
          register_handler(PAGE_TYPE, :show, api: :public, handler: Show)
          register_handler(SECTION_TYPE, :index, api: OPERATIONS_API, handler: Index)
          register_handler(SECTION_TYPE, :show, api: OPERATIONS_API, handler: Show)
          register_handler(PAGE_TYPE, :index, api: OPERATIONS_API, handler: Index)
          register_handler(PAGE_TYPE, :show, api: OPERATIONS_API, handler: Show)
        end

        def register_public_refusals!
          %i[index show create update destroy].each do |action|
            register_handler(SECTION_TYPE, action, api: :public, handler: RefusePublicSections)
            register_handler(CENTER_TYPE, action, api: :public, handler: RefusePublicCenters)
          end
        end

        def register_handler(...)
          Registration.register_handler(...)
        end
      end
    end
  end
end
