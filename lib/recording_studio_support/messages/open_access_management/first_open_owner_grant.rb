# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    module OpenAccessManagement
      # Messages `create_group` grants the opener `:admin` on a new MessageGroup.
      # Accessible's default authorizer requires existing `:admin`, so the first
      # owner grant is allowed only for that empty group under the support mount.
      module FirstOpenOwnerGrant
        module_function

        def allowed?(recording:, actor:, context:)
          return false if context.blank?
          return false unless same_actor?(actor, context[:actor])
          return false unless message_group?(recording)
          return false unless under_mount?(recording, context[:mount])
          return false unless empty_direct_access?(recording)

          true
        end

        def message_group?(recording)
          recording.respond_to?(:recordable_type) &&
            recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
        end

        def under_mount?(recording, mount)
          return false if recording.blank? || mount.blank?

          parent = recording.parent_recording if recording.respond_to?(:parent_recording)
          return same_recording?(parent, mount) if parent.present?

          parent_id_matches_mount?(recording, mount)
        end

        def parent_id_matches_mount?(recording, mount)
          return false unless recording.respond_to?(:parent_recording_id)
          return false unless mount.respond_to?(:id)
          return false if recording.parent_recording_id.blank? || mount.id.blank?

          recording.parent_recording_id == mount.id
        end

        def empty_direct_access?(recording)
          RecordingStudioAccessible.access_recordings_for(recording).none?
        rescue StandardError
          false
        end

        def same_actor?(left, right)
          return false if left.blank? || right.blank?
          return true if left.equal?(right)

          Messages.same_actor?(left, right)
        rescue NoMethodError
          false
        end

        def same_recording?(left, right)
          return false if left.blank? || right.blank?
          return true if left.equal?(right)
          return false unless left.respond_to?(:id) && right.respond_to?(:id)

          left.id.present? && left.id == right.id
        end
      end
    end
  end
end
