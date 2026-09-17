# frozen_string_literal: true

require_relative "api/access"
require_relative "api/payload"
require_relative "api/serialize"
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

        register_types!
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

      def register_types!
        RecordingStudioApi.register_recordable_type_api(
          SECTION_TYPE,
          serializer: ->(section, **) {
            { title: section.title, slug: section.slug, icon: section.icon }
          },
          output_keys: %i[title slug icon],
          writable_attributes: %i[title icon],
          sortable_attributes: %i[title],
          operations: %i[index show create update destroy],
          relationships: {
            pages: {
              source: :children,
              child_type: PAGE_TYPE,
              many: true,
              include: :request,
              serializer: ->(page, **) {
                {
                  title: page.title,
                  description: page.description,
                  icon: page.icon,
                  body: page.body
                }
              },
              output_keys: %i[title description icon body],
              limit: 50,
              endpoints: %i[index show create update destroy]
            }
          }
        )

        RecordingStudioApi.register_recordable_type_api(
          PAGE_TYPE,
          serializer: ->(page, **) {
            {
              title: page.title,
              description: page.description,
              icon: page.icon,
              body: page.body
            }
          },
          output_keys: %i[title description icon body],
          writable_attributes: %i[title description icon body],
          sortable_attributes: %i[title],
          operations: %i[index show create update destroy],
          capability_actions: %i[move]
        )
      end

      def wrap_operations!
        wrap(
          RecordingStudioApi::Services::ResourceOperations::Create,
          Intercept::Create
        )
        wrap(
          RecordingStudioApi::Services::ResourceOperations::Update,
          Intercept::Update
        )
        wrap(
          RecordingStudioApi::Services::ResourceOperations::Destroy,
          Intercept::Destroy
        )
        wrap(
          RecordingStudioApi::Services::ResourceOperations::Index,
          Intercept::Index
        )
        wrap(
          RecordingStudioApi::Services::ResourceOperations::Show,
          Intercept::Show
        )
        wrap_move_handlers!
      end

      def wrap_move_handlers!
        if defined?(RecordingStudioApi::Services::MoveRecording)
          wrap(RecordingStudioApi::Services::MoveRecording, Intercept::Move)
        end
        return unless defined?(RecordingStudio::Moveable::Api::MoveRecording)

        wrap(RecordingStudio::Moveable::Api::MoveRecording, Intercept::Move)
      end

      def wrap_controllers!
        wrap("RecordingStudioApi::Api::V1::ResourcesController".safe_constantize, ResourcesLookup)
        wrap("RecordingStudioApi::Api::V1::MemberActionsController".safe_constantize, MemberActionsLookup)
        wrap(
          "RecordingStudioApi::Api::V1::RelationshipResourcesController".safe_constantize,
          RelationshipLookup
        )
      end

      def wrap(klass, mod)
        return if klass.nil?
        return if klass.ancestors.include?(mod)

        klass.prepend(mod)
      end
    end
  end
end
