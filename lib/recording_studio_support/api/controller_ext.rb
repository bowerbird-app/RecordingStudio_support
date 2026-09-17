# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module ResourcesLookup
      def resource_recording(include_trashed: false)
        type = resolve_recordable_type!
        return super unless RecordingStudioSupport::Api.support_type?(type)

        relation = RecordingStudio::Recording.where(recordable_type: type)
        relation = relation.where(trashed_at: nil) unless include_trashed
        recording = relation.find_by(id: params[:id])
        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if recording.nil?

        recording
      end

      def render_dispatched_resource_action!(operation_name, recording: nil)
        operation = resolve_resource_action!(operation_name)
        result = operation.handler.call(resource_operation_context(recording: recording))
        result.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
        render json: result.fetch(:json), status: result.fetch(:status, :ok)
      end
    end

    module MemberActionsLookup
      def resource_recording
        type = RecordingStudioApi.recordable_type_for_resource(params[:resource], api: current_api_key)
        raise RecordingStudioApi::NotFoundError, "Unknown API resource #{params[:resource]}" if type.blank?
        return super unless RecordingStudioSupport::Api.support_type?(type)

        find_support_recording!(type)
      end

      def authorize_action!(action, context)
        return if support_page_move?(action, context)

        super
      end

      def action_params(action)
        return super unless support_page_recording?

        filtered = filtered_member_params
        return filtered if action.input_contract.nil?

        contract_value!(action, filtered)
      end

      private

      def find_support_recording!(type)
        recording = RecordingStudio::Recording.where(
          recordable_type: type,
          trashed_at: nil
        ).find_by(id: params[:id])
        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if recording.nil?

        recording
      end

      def support_page_move?(action, context)
        context.recording&.recordable_type == RecordingStudioSupport::Api::PAGE_TYPE &&
          action.name.to_s == "move"
      end

      def support_page_recording?
        resource_recording.recordable_type == RecordingStudioSupport::Api::PAGE_TYPE
      rescue RecordingStudioApi::NotFoundError
        false
      end

      def filtered_member_params
        raw_params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : {}
        reserved = RecordingStudioApi::Api::V1::MemberActionsController::RESERVED_ACTION_PARAM_KEYS +
                   %w[member_action api_key api_version]
        filtered = raw_params.except(*reserved)
        filtered.respond_to?(:deep_symbolize_keys) ? filtered.deep_symbolize_keys : {}
      end

      def contract_value!(action, filtered)
        contract_result = action.input_contract.call(filtered)
        return contract_result.value if contract_result.success?

        raise RecordingStudioApi::InvalidActionInputError.new(
          "Invalid input for action #{action.name}",
          details: contract_result.errors
        )
      end
    end

    module RelationshipLookup
      def parent_recording
        type = resolve_recordable_type!
        return super unless type == RecordingStudioSupport::Api::SECTION_TYPE

        recording = RecordingStudio::Recording.where(
          recordable_type: type,
          trashed_at: nil
        ).find_by(id: params[:parent_id])
        raise RecordingStudioApi::NotFoundError, "Parent resource was not found in this API scope" if recording.nil?

        recording
      end

      def child_scope(include_trashed: false)
        return super unless support_section_parent?

        scoped_children(include_trashed: include_trashed)
      end

      def assert_nested_operation!(operation, role:, include_trashed: false)
        return super unless support_section_parent?

        authorize_nested!(role)
        assert_pages_collection!(operation)
      end

      def authorize_child!(child)
        return super unless support_section_parent?

        unless Access.can_view_recording?(access_context, child)
          raise RecordingStudioApi::NotFoundError, "Relationship resource was not found in this API scope"
        end
        if hide_draft_page?(child)
          raise RecordingStudioApi::NotFoundError, "Relationship resource was not found in this API scope"
        end

        child
      end

      private

      def support_section_parent?
        resolve_recordable_type! == RecordingStudioSupport::Api::SECTION_TYPE
      rescue RecordingStudioApi::NotFoundError
        false
      end

      def access_context
        Struct.new(:access_grant).new(current_access_grant)
      end

      def hide_draft_page?(child)
        return false if Access.can_view_as_staff?(access_context)
        return false unless child.recordable_type == RecordingStudioSupport::Api::PAGE_TYPE

        !child.recordable.indexable?
      end

      def scoped_children(include_trashed:)
        relation = RecordingStudio::Recording.where(
          parent_recording_id: parent_recording.id,
          recordable_type: relationship.child_type
        )
        relation = relation.where(trashed_at: nil) unless include_trashed
        return relation if Access.can_view_as_staff?(access_context)
        return relation unless relationship.child_type == RecordingStudioSupport::Api::PAGE_TYPE

        relation.where(recordable_id: SupportPage.indexable.select(:id))
      end

      def authorize_nested!(role)
        if role == :edit
          Access.authorize_edit!(access_context)
        else
          Access.authorize_view!(access_context, parent_recording)
        end
      end

      def assert_pages_collection!(operation)
        unless relationship.source == :children && relationship.many
          raise RecordingStudioApi::UnsupportedActionError,
                "#{relationship_name} is not a direct child collection"
        end
        unless relationship.endpoints.include?(operation)
          raise RecordingStudioApi::UnsupportedActionError,
                "#{operation} is not enabled for #{relationship_name}"
        end

        assert_operation_enabled!(relationship.child_type, operation)
      end
    end
  end
end
