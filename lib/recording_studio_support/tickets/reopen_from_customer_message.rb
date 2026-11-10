# frozen_string_literal: true

module RecordingStudioSupport
  module Tickets
    # A customer message on a resolved ticket reopens it through Update.
    class ReopenFromCustomerMessage
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, actor:)
        @group_recording = group_recording
        @actor = actor
      end

      def call
        return if @group_recording.blank? || @actor.blank?
        return if Messages.staff_actor?(@actor)

        ticket = Tickets.tickets_by_group_id([@group_recording.id])[@group_recording.id]
        return if ticket.blank?
        return unless ticket.status.to_s == "resolved"

        Tickets.update!(ticket, actor: @actor, status: :open)
      end
    end
  end
end
