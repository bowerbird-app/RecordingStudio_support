# frozen_string_literal: true

module RecordingStudioSupport
  class StaffTicketsController < ApplicationController
    skip_before_action :require_support_root!, raise: false

    helper RecordingStudioSupport::MessagesInboxHelper
    include RecordingStudioSupport::MessagesInboxHelper

    before_action :require_signed_in_actor!
    before_action :require_staff_actor!
    before_action :set_ticket

    def update
      recording = RecordingStudioSupport::Tickets.recording_for!(@ticket)
      RecordingStudioSupport::Tickets.update!(
        recording,
        actor: current_support_actor,
        **ticket_changes
      )
      @ticket = RecordingStudioSupport::Tickets.find!(@ticket.id)
      respond_after_update
    rescue ActiveRecord::RecordInvalid => e
      redirect_to staff_messages_return_to, alert: update_error_message(e.record)
    end

    private

    def respond_after_update
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to staff_messages_return_to, notice: "Ticket updated." }
      end
    end

    def set_ticket
      @ticket = RecordingStudioSupport::Tickets.find!(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ticket_changes
      attrs = params.fetch(:ticket, {}).permit(:status, :priority).to_h.compact_blank.stringify_keys
      attrs.slice("status", "priority").symbolize_keys
    end

    def update_error_message(record)
      record.errors.full_messages.to_sentence.presence || "Could not update."
    end

    def staff_messages_return_to
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      group = RecordingStudioSupport::Tickets.group_recording_for(@ticket)
      "#{path}/messages?group_id=#{group&.id}"
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
  end
end
