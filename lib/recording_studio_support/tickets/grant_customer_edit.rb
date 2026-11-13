# frozen_string_literal: true

module RecordingStudioSupport
  module Tickets
    # The only direct grant on a ticket conversation. The granter is an admin
    # already held on an ancestor. That admin is not added to the group.
    class GrantCustomerEdit
      def self.call(group:, actor:)
        new(group:, actor:).call
      end

      def initialize(group:, actor:)
        @group = group
        @actor = actor
      end

      def call
        return if Messages.support_team_actor?(@actor)

        RecordingStudioMessages.allow_membership_change do
          manager = inherited_admin
          raise RecordingStudioMessages::Error, "Support messages are not available" if manager.blank?

          grant_edit!(manager)
        end
      end

      private

      def grant_edit!(manager)
        result = RecordingStudioAccessible.grant_access(
          recording: @group,
          actor: @actor,
          role: :edit,
          manager_actor: manager
        )
        return if result.success?

        raise RecordingStudioMessages::Error, result.error.to_s
      end

      def inherited_admin
        return @actor if admin_on?(@actor, @group)

        ancestor = @group
        while ancestor
          actor = admin_holder_on(ancestor)
          return actor if actor

          ancestor = ancestor.parent_recording
        end
        nil
      end

      def admin_holder_on(recording)
        RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
          actor = access_recording.recordable&.actor
          return actor if actor.present? && admin_on?(actor, @group)
        end
        nil
      end

      def admin_on?(actor, recording)
        RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :admin)
      end
    end
  end
end
