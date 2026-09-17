# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Serialize
      module_function

      def recording(recording, context:)
        RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          recording,
          version: context.api_version,
          api: context.api_key,
          context: relationship_context(recording, context)
        )
      end

      def collection(recordings, context:, meta:)
        relationship_context = RecordingStudioApi::RelationshipContext.for(
          recordings: recordings,
          include_values: context.params[:include],
          scoped_recordings: recordings,
          api_key: context.api_key,
          api_version: context.api_version,
          access_grant: context.access_grant,
          params: context.params,
          batch: true
        )

        {
          resource: context.resource_name,
          type: context.recordable_type.demodulize,
          records: recordings.map do |entry|
            RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
              entry,
              version: context.api_version,
              api: context.api_key,
              context: relationship_context
            )
          end,
          meta: meta
        }
      end

      def relationship_context(recording, context)
        RecordingStudioApi::RelationshipContext.for(
          recordings: [recording],
          include_values: context.params[:include],
          scoped_recordings: RecordingStudio::Recording.where(id: recording.id),
          api_key: context.api_key,
          api_version: context.api_version,
          access_grant: context.access_grant,
          params: context.params
        )
      end
    end
  end
end
