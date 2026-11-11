# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Create
      include Idempotency

      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        cached = cached_idempotent_response
        return cached if cached

        Access.authorize_edit!(context)
        result = { json: Serialize.recording(create_recording!, context: context), status: :created }
        store_idempotent_response(result)
        result
      end

      private

      attr_reader :context

      def create_recording!
        actor = Access.write_actor(context)
        attrs = Payload.attributes(context)
        return create_section!(actor, attrs) if context.recordable_type == Api::SECTION_TYPE

        create_page!(actor, attrs)
      end

      def create_section!(actor, attrs)
        create_with_parent_errors!(help_section: true) do
          Sections.create!(
            root_recording: parent_recording!,
            title: attrs[:title],
            icon: attrs[:icon],
            actor: actor
          )
        end
      end

      def create_page!(actor, attrs)
        create_with_parent_errors! do
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

      def create_with_parent_errors!(help_section: false)
        yield
      rescue ArgumentError => e
        raise unless help_section && e.message == "Help sections belong under Support."

        raise_invalid_parent_input!(e.message)
      rescue RecordingStudio::InvalidParent => e
        raise_invalid_parent_input!(e.message)
      end

      def parent_recording!
        recording = context_parent_recording
        return recording if recording

        parent_id = Payload.parent_id(context)
        raise_missing_parent! if parent_id.blank?

        find_kept_parent!(parent_id)
      rescue ActiveRecord::RecordNotFound
        Lookup.raise_not_found("Resource was not found")
      end

      def context_parent_recording
        return unless context.respond_to?(:parent_recording)

        context.parent_recording
      end

      def find_kept_parent!(parent_id)
        return Lookup.workspace!(id: parent_id) if context.recordable_type == Api::SECTION_TYPE

        RecordingStudio::Recording.where(trashed_at: nil).find(parent_id)
      end

      def raise_invalid_parent_input!(message)
        details = [{
          attribute: :parent_id,
          message: "is not allowed for #{context.recordable_type}",
          full_message: message,
          type: :invalid
        }]
        raise RecordingStudioApi::InvalidActionInputError.new(message, details: details)
      end

      def raise_missing_parent!
        details = [{
          attribute: :parent_id,
          message: "is required",
          full_message: "Parent is required",
          type: :blank
        }]
        raise RecordingStudioApi::InvalidActionInputError.new(
          "parent_id is required for #{context.recordable_type}",
          details: details
        )
      end
    end
  end
end
