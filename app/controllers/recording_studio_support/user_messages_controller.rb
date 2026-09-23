# frozen_string_literal: true

module RecordingStudioSupport
  class UserMessagesController < ApplicationController
    skip_before_action :require_support_root!, raise: false

    helper RecordingStudioMessages::PanelHelper if defined?(RecordingStudioMessages::PanelHelper)
    helper RecordingStudioMessages::InboxHelper if defined?(RecordingStudioMessages::InboxHelper)
    helper RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
    helper RecordingStudioSupport::MessagesDeskHelper

    before_action :require_signed_in_actor!
    helper_method :staff_desk_return_to

    def show
      @group_recording = bootstrap_user_group!
      return head :not_found if @group_recording.blank?

      @mount_recording = @group_recording.parent_recording
      @group_recordings = [@group_recording]
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    private

    def bootstrap_user_group!
      group = RecordingStudioSupport::Messages.find_or_create_user_group(
        actor: current_support_actor
      )
      return if group.blank?

      RecordingStudioSupport::Messages.sync_staff_grants!(
        group_recording: group,
        manager_actor: current_support_actor
      )
      group
    end

    def staff_desk_return_to
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      base = "#{path}/messages"
      return base if @group_recording.blank?

      "#{base}?group_id=#{@group_recording.id}"
    end

    def require_signed_in_actor!
      return if current_support_actor.present?

      authenticate_user! if respond_to?(:authenticate_user!)
      return if current_support_actor.present?

      head :unauthorized
    end
  end
end
