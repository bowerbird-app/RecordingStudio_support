# frozen_string_literal: true

module RecordingStudioSupport
  class UserMessagesController < ApplicationController
    skip_before_action :require_support_root!, raise: false

    helper RecordingStudioMessages::PanelHelper if defined?(RecordingStudioMessages::PanelHelper)
    helper RecordingStudioMessages::InboxHelper if defined?(RecordingStudioMessages::InboxHelper)
    helper RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
    helper RecordingStudioSupport::MessagesDeskHelper

    before_action :require_signed_in_actor!
    before_action :set_ticket, only: :show
    helper_method :staff_desk_return_to

    def index
      @tickets = RecordingStudioSupport::Tickets.for_actor(current_support_actor)
    end

    def new
      @ticket = SupportTicket.new(priority: :normal)
      @body = ""
    end

    def create
      @ticket = RecordingStudioSupport::Tickets.open!(
        actor: current_support_actor,
        subject: ticket_params[:subject],
        body: ticket_params[:body],
        priority: ticket_params[:priority].presence || :normal
      )
      redirect_to help_message_path_for(@ticket), notice: "Sent. We’ll take a look."
    rescue ArgumentError, ActiveRecord::RecordInvalid, RecordingStudioMessages::Error => e
      @ticket = SupportTicket.new(
        subject: ticket_params[:subject],
        priority: ticket_params[:priority].presence || :normal
      )
      @ticket.errors.add(:base, e.message)
      @body = ticket_params[:body]
      render :new, status: :unprocessable_entity
    end

    def show
      @group_recording = @ticket.message_group_recording
      return head :not_found if @group_recording.blank?
      return deny_support_access! unless ticket_visible_to_actor?

      RecordingStudioSupport::Messages.sync_staff_grants!(
        group_recording: @group_recording,
        manager_actor: current_support_actor
      )

      @mount_recording = @group_recording.parent_recording
      @group_recordings = [@group_recording]
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    private

    def set_ticket
      @ticket = RecordingStudioSupport::Tickets.find!(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ticket_visible_to_actor?
      RecordingStudioSupport::Messages.group_owner?(@group_recording, current_support_actor) ||
        RecordingStudioSupport::Messages.staff_actor?(current_support_actor)
    end

    def ticket_params
      params.fetch(:ticket, {}).permit(:subject, :body, :priority)
    end

    def help_message_path_for(ticket)
      public_path = RecordingStudioSupport.configuration.public_pages_path.to_s.chomp("/")
      "#{public_path}/messages/#{ticket.id}"
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
