# frozen_string_literal: true

module RecordingStudioSupport
  module Tickets
    # A customer message on a resolved ticket reopens it through Update.
    class ReopenFromCustomerMessage
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, actor:, message_recording: nil)
        @group_recording = group_recording
        @actor = actor
        @message_recording = message_recording
      end

      def call
        return unless customer_reply?

        ticket = ticket_for_group
        return unless resolved?(ticket)

        writer = writer_for(ticket)
        return if writer.blank?

        apply_reopen!(ticket, writer)
      end

      private

      def customer_reply?
        @group_recording.present? && @actor.present? && !Messages.support_team_actor?(@actor)
      end

      def ticket_for_group
        Tickets.tickets_by_group_id([@group_recording.id])[@group_recording.id]
      end

      def resolved?(ticket)
        ticket.present? && ticket.status.to_s == "resolved"
      end

      def apply_reopen!(ticket, writer)
        Tickets.update!(
          ticket,
          actor: writer,
          impersonator: @actor,
          status: :open,
          metadata: {
            "message_id" => @message_recording&.id,
            "message_group_id" => @group_recording.id
          }.compact
        )
      end

      def writer_for(ticket)
        recording = Tickets.ticket_recording_for(ticket)
        return if recording.blank?

        editors = RecordingStudioAccessible.actors_with_access(
          recording: recording,
          minimum_role: :edit
        ).map(&:actor)
        staff = editors.select { |person| Messages.support_team_actor?(person) }
        preferred = staff.presence || editors
        preferred.find { |person| Api::Access.person?(person) } || preferred.first
      end
    end
  end
end
