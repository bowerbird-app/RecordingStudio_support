# frozen_string_literal: true

require_relative "intercept/handlers"

module RecordingStudioSupport
  module Api
    module Intercept
      module_function

      def operation_pairs
        ops = RecordingStudioApi::Services::ResourceOperations
        [
          [ops::Create, Create],
          [ops::Update, Update],
          [ops::Destroy, Destroy],
          [ops::Index, Index],
          [ops::Show, Show]
        ]
      end

      def move_classes
        [
          "RecordingStudioApi::Services::MoveRecording".safe_constantize,
          "RecordingStudio::Moveable::Api::MoveRecording".safe_constantize
        ].compact
      end

      def controller_pairs
        [
          ["RecordingStudioApi::Api::V1::ResourcesController", ResourcesLookup],
          ["RecordingStudioApi::Api::V1::MemberActionsController", MemberActionsLookup],
          ["RecordingStudioApi::Api::V1::RelationshipResourcesController", RelationshipLookup],
          ["RecordingStudioApi::Api::V1::RelationshipResourcesController", NestedPageSearch]
        ].map { |name, mod| [name.safe_constantize, mod] }
      end
    end
  end
end
