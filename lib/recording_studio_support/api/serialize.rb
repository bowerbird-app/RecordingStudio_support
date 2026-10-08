# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Serialize
      SECTION = lambda { |section, **|
        { title: section.title, slug: section.slug, icon: section.icon }
      }
      PAGE = lambda { |page, **|
        {
          title: page.title,
          description: page.description,
          icon: page.icon,
          body: page.body
        }
      }

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
        {
          resource: context.resource_name,
          type: context.recordable_type.demodulize,
          records: recordings.map { |entry| serialize_entry(entry, context, recordings) },
          meta: meta
        }
      end

      def serialize_entry(entry, context, recordings)
        RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          entry,
          version: context.api_version,
          api: context.api_key,
          context: collection_relationship_context(recordings, context)
        )
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

      def collection_relationship_context(recordings, context)
        RecordingStudioApi::RelationshipContext.for(
          recordings: recordings,
          include_values: context.params[:include],
          scoped_recordings: recordings,
          api_key: context.api_key,
          api_version: context.api_version,
          access_grant: context.access_grant,
          params: context.params,
          batch: true
        )
      end
    end
  end
end
