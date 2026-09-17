# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Intercept
      module Create
        def call
          return RecordingStudioSupport::Api::Create.call(context) if support_type?

          super
        end

        private

        def support_type?
          RecordingStudioSupport::Api.support_type?(context.recordable_type)
        end
      end

      module Update
        def call
          return RecordingStudioSupport::Api::Update.call(context) if support_type?

          super
        end

        private

        def support_type?
          RecordingStudioSupport::Api.support_type?(context.recordable_type)
        end
      end

      module Destroy
        def call
          return RecordingStudioSupport::Api::Destroy.call(context) if support_type?

          super
        end

        private

        def support_type?
          RecordingStudioSupport::Api.support_type?(context.recordable_type)
        end
      end

      module Index
        def call
          return RecordingStudioSupport::Api::Index.call(context) if support_type?

          super
        end

        private

        def support_type?
          RecordingStudioSupport::Api.support_type?(context.recordable_type)
        end
      end

      module Show
        def call
          return RecordingStudioSupport::Api::Show.call(context) if support_type?

          super
        end

        private

        def support_type?
          RecordingStudioSupport::Api.support_type?(context.recordable_type)
        end
      end

      module Move
        def call
          recording = context.recording
          if recording&.recordable_type == RecordingStudioSupport::Api::PAGE_TYPE
            return RecordingStudioSupport::Api::Move.call(context)
          end

          super
        end
      end
    end
  end
end
