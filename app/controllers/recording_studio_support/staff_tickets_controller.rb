# frozen_string_literal: true

module RecordingStudioSupport
  class StaffTicketsController < ApplicationController
    skip_before_action :require_support_root!, raise: false

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

      redirect_to staff_messages_return_to(recording), notice: "Ticket updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to staff_messages_return_to(recording), alert: update_error_message(e.record)
    end

    private

    def set_ticket
      @ticket = RecordingStudioSupport::Tickets.find!(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ticket_changes
      changes = status_and_priority_changes
      changes[:assignee] = resolve_assignee(ticket_params[:assignee]) if ticket_params.key?(:assignee)
      changes
    end

    def status_and_priority_changes
      attrs = params.fetch(:ticket, {}).permit(:status, :priority).to_h.compact_blank.stringify_keys
      attrs.slice("status", "priority").symbolize_keys
    end

    def ticket_params
      params.fetch(:ticket, {})
    end

    def resolve_assignee(raw)
      return if raw.blank?

      RecordingStudioSupport::Messages.staff_actors.find do |actor|
        "#{actor.class.name}:#{actor.id}" == raw.to_s
      end
    end

    def update_error_message(record)
      record.errors.full_messages.to_sentence.presence || "Could not update."
    end

    def staff_messages_return_to(recording = nil)
      recording ||= RecordingStudioSupport::Tickets.recording_for!(@ticket)
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      "#{path}/messages?group_id=#{recording.parent_recording_id}"
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
