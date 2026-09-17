# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Registration
      module_function

      def register!
        register_sections!
        register_pages!
      end

      def register_sections!
        RecordingStudioApi.register_recordable_type_api(
          SECTION_TYPE,
          serializer: Serialize::SECTION,
          output_keys: %i[title slug icon],
          writable_attributes: %i[title icon],
          sortable_attributes: %i[title],
          operations: %i[index show create update destroy],
          relationships: { pages: pages_relationship }
        )
      end

      def register_pages!
        RecordingStudioApi.register_recordable_type_api(
          PAGE_TYPE,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          writable_attributes: %i[title description icon body],
          sortable_attributes: %i[title],
          operations: %i[index show create update destroy],
          capability_actions: %i[move]
        )
      end

      def pages_relationship
        {
          source: :children,
          child_type: PAGE_TYPE,
          many: true,
          include: :request,
          serializer: Serialize::PAGE,
          output_keys: %i[title description icon body],
          limit: 50,
          endpoints: %i[index show create update destroy]
        }
      end
    end
  end
end
