# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class PublishableTransition
      def self.call(context, action_name)
        new(context, action_name).call
      end

      def initialize(context, action_name)
        @context = context
        @action_name = action_name
      end

      def call
        Access.authorize_edit!(context)
        recording = Lookup.page!(id: Payload.member_id(context))
        outcome = RecordingStudioPublishable::Api::Perform.apply(publishable_context(recording), action_name)
        { json: RecordingStudioPublishable::Api::PublishableSnapshot.call(outcome) }
      end

      private

      attr_reader :context, :action_name

      def publishable_context(recording)
        RecordingStudioApi::ActionContext.new(
          recording: recording,
          api_client: context.api_client,
          credential: context.credential,
          access_recording: context.access_recording,
          access_grant: context.access_grant,
          root_recording: context.root_recording,
          params: context.params
        )
      end
    end

    class Publish
      def self.call(context)
        PublishableTransition.call(context, :publish)
      end
    end

    class Unpublish
      def self.call(context)
        PublishableTransition.call(context, :unpublish)
      end
    end
  end
end
