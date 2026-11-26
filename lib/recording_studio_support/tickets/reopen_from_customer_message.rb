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
        return if Messages.support_team_actor?(@actor)

        ticket = Tickets.tickets_by_group_id([@group_recording.id])[@group_recording.id]
        return if ticket.blank?
        return unless ticket.status.to_s == "resolved"

        writer = writer_for(ticket)
        return if writer.blank?

        Tickets.update!(ticket, actor: writer, status: :open)
      end

      private

      def writer_for(ticket)
        recording = Tickets.ticket_recording_for(ticket)
        return if recording.blank?

        editors = RecordingStudioAccessible.actors_with_access(
          recording: recording,
          minimum_role: :edit
        ).map(&:actor)
        editors.find { |person| Messages.support_team_actor?(person) } || editors.first
      end
    end
  end
end
