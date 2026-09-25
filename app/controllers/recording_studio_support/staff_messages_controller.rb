# frozen_string_literal: true

module RecordingStudioSupport
  class StaffMessagesController < ApplicationController
    skip_before_action :require_support_root!, raise: false

    helper RecordingStudioMessages::PanelHelper if defined?(RecordingStudioMessages::PanelHelper)
    helper RecordingStudioMessages::InboxHelper if defined?(RecordingStudioMessages::InboxHelper)
    helper RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
    helper RecordingStudioSupport::MessagesDeskHelper

    before_action :require_signed_in_actor!
    before_action :require_staff_actor!
    helper_method :user_desk_return_to

    def show
      @mount_recording = RecordingStudioSupport::Messages.ensure_message_mount(
        actor: current_support_actor
      )
      return head :not_found if @mount_recording.blank?

      @group_recordings = RecordingStudioMessages.viewable_group_recordings(
        actor: current_support_actor,
        mount_recording: @mount_recording
      )
      load_tickets_for_groups
      load_selected_conversation
      sync_selected_group_grants
    end

    private

    def user_desk_return_to
      public_path = RecordingStudioSupport.configuration.public_pages_path.to_s.chomp("/")
      return "#{public_path}/messages" if @ticket.blank?

      "#{public_path}/messages/#{@ticket.id}"
    end

    def require_signed_in_actor!
      return if current_support_actor.present?

      authenticate_user! if respond_to?(:authenticate_user!)
      return if current_support_actor.present?

      head :unauthorized
    end

    def require_staff_actor!
      return if RecordingStudioSupport::Messages.staff_actor?(current_support_actor)

      deny_support_access!
    end

    def load_tickets_for_groups
      @tickets_by_group_id = RecordingStudioSupport::Tickets
        .for_message_group_ids(@group_recordings.map(&:id))
        .index_by(&:message_group_id)
    end

    def load_selected_conversation
      @group_recording = selected_group_from_params || first_ready_group
      @ticket = @tickets_by_group_id[@group_recording&.id]
      return if @group_recording.blank?

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    def selected_group_from_params
      id = params[:group_id].presence
      return if id.blank?

      @group_recordings.find { |group| group.id.to_s == id.to_s }
    end

    def first_ready_group
      @group_recordings.find do |group|
        group.recordable&.title.to_s.strip.present? &&
          RecordingStudioMessages.message_recordings(group).last&.recordable&.body.present?
      end || @group_recordings.first
    end

    def sync_selected_group_grants
      return if @group_recording.blank?

      owner = group_owner_actor(@group_recording) || current_support_actor
      RecordingStudioSupport::Messages.sync_staff_grants!(
        group_recording: @group_recording,
        manager_actor: owner
      )
    end

    def group_owner_actor(group_recording)
      RecordingStudioMessages.granted_actors(group_recording).find do |actor|
        RecordingStudioSupport::Messages.group_owner?(group_recording, actor)
      end
    end
  end
end
