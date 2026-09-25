# frozen_string_literal: true

module RecordingStudioSupport
  class StaffTicketsController < ApplicationController
    skip_before_action :require_support_root!, raise: false

    before_action :require_signed_in_actor!
    before_action :require_staff_actor!
    before_action :set_ticket

    def update
      @ticket.assign_attributes(ticket_update_attrs)
      apply_assignee!
      @ticket.save!

      redirect_to staff_messages_return_to, notice: "Ticket updated."
    rescue ActiveRecord::RecordInvalid
      redirect_to staff_messages_return_to, alert: @ticket.errors.full_messages.to_sentence.presence || "Could not update."
    end

    private

    def set_ticket
      @ticket = RecordingStudioSupport::Tickets.find!(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ticket_update_attrs
      params.fetch(:ticket, {}).permit(:status, :priority).to_h.compact_blank
    end

    def apply_assignee!
      raw = params.fetch(:ticket, {})[:assignee]
      return unless params.fetch(:ticket, {}).key?(:assignee)

      if raw.blank?
        @ticket.assignee = nil
        return
      end

      type, id = raw.to_s.split(":", 2)
      staff = RecordingStudioSupport::Messages.staff_actors.find do |actor|
        actor.class.name == type && actor.id.to_s == id.to_s
      end
      @ticket.assignee = staff
    end

    def staff_messages_return_to
      path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
      group_id = @ticket.message_group_id
      "#{path}/messages?group_id=#{group_id}"
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
