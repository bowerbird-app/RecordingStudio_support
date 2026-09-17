# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Create
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        if (cached = cached_idempotent_response)
          return cached
        end

        Access.authorize_edit!(context)
        created = create_recording!
        result = {
          json: Serialize.recording(created, context: context),
          status: :created
        }
        store_idempotent_response(result)
        result
      end

      private

      attr_reader :context

      def create_recording!
        actor = Access.actor_for(context)
        attrs = Payload.attributes(context)

        if context.recordable_type == Api::SECTION_TYPE
          Sections.create!(
            root_recording: parent_recording!,
            title: attrs[:title],
            icon: attrs[:icon],
            actor: actor
          )
        else
          Pages.create!(
            parent_recording: parent_recording!,
            title: attrs[:title],
            body: attrs[:body],
            description: attrs[:description],
            icon: attrs[:icon],
            actor: actor
          )
        end
      end

      def parent_recording!
        return context.parent_recording if context.parent_recording

        parent_id = Payload.parent_id(context)
        if parent_id.blank?
          raise RecordingStudioApi::InvalidActionInputError.new(
            "parent_id is required for #{context.recordable_type}",
            details: [
              {
                attribute: :parent_id,
                message: "is required",
                full_message: "Parent is required",
                type: :blank
              }
            ]
          )
        end

        parent = RecordingStudio::Recording.find_by(id: parent_id, trashed_at: nil)
        raise RecordingStudioApi::NotFoundError, "Parent resource was not found" if parent.nil?

        parent
      end

      def cached_idempotent_response
        key = context.idempotency_key
        return if key.blank? || !defined?(RecordingStudioApi::IdempotencyStore)

        payload = RecordingStudioApi::IdempotencyStore.fetch(
          api: context.api_key,
          client_id: context.api_client.id,
          key: key
        )
        return if payload.blank?

        {
          json: payload.fetch("json"),
          status: payload.fetch("status", "created").to_sym
        }
      end

      def store_idempotent_response(result)
        key = context.idempotency_key
        return if key.blank? || !defined?(RecordingStudioApi::IdempotencyStore)

        RecordingStudioApi::IdempotencyStore.write(
          api: context.api_key,
          client_id: context.api_client.id,
          key: key,
          payload: result.fetch(:json),
          status: result.fetch(:status, :created).to_s
        )
      end
    end
  end
end
