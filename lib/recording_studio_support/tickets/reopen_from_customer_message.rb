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
        if writer.blank?
          log_missing_writer(ticket)
          return
        end

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

        staff = RecordingStudioAccessible.actors_with_access(
          recording: recording,
          minimum_role: :edit
        ).map(&:actor).select { |actor| Messages.support_team_actor?(actor) }
        staff.find { |actor| Api::Access.person?(actor) }
      end

      def log_missing_writer(ticket)
        return unless defined?(Rails) && Rails.logger

        Rails.logger.warn(
          "RecordingStudioSupport could not reopen ticket #{ticket.id}: " \
          "no support-team person with edit access."
        )
      end
    end
  end
end
