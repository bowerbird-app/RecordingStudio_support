# frozen_string_literal: true

module RecordingStudioSupport
  module Tickets
    # Revises a ticket recording. One "updated" event carries the diff.
    class Update
      def self.call(...)
        new(...).call
      end

      def initialize(ticket_or_recording, actor:, status: UNSET, priority: UNSET, assignee: UNSET)
        @ticket_or_recording = ticket_or_recording
        @actor = actor
        @status = status
        @priority = priority
        @assignee = assignee
      end

      def call
        recording = coerce_recording
        recording.with_lock do
          current = recording.reload.recordable
          changes, attributes = diff(current)
          return recording if changes.empty?

          revise(recording, changes, attributes)
        end
      end

      private

      def coerce_recording
        return @ticket_or_recording if @ticket_or_recording.is_a?(RecordingStudio::Recording)

        Tickets.recording_for!(@ticket_or_recording)
      end

      def diff(current)
        changes = {}
        attributes = {}
        assign_change(changes, attributes, "status", current.status, @status)
        assign_change(changes, attributes, "priority", current.priority, @priority)
        assign_assignee(changes, attributes, current)
        [changes, attributes]
      end

      def assign_change(changes, attributes, name, current_value, next_value)
        return unless Copy.provided?(next_value)
        return if next_value.to_s == current_value.to_s

        changes[name] = [current_value.to_s, next_value.to_s]
        attributes[name.to_sym] = next_value
      end

      def assign_assignee(changes, attributes, current)
        return unless Copy.provided?(@assignee)
        return if assignee_key(@assignee) == assignee_key(current.assignee)

        changes["assignee"] = [assignee_key(current.assignee), assignee_key(@assignee)]
        attributes[:assignee] = @assignee
      end

      def assignee_key(assignee)
        return if assignee.blank?

        "#{assignee.class.name}:#{assignee.id}"
      end

      def revise(recording, changes, attributes)
        recording.root_recording.revise(
          recording,
          actor: @actor,
          metadata: { "changes" => changes }
        ) do |ticket|
          attributes.each { |name, value| ticket.public_send(:"#{name}=", value) }
          ticket.created_at = recording.created_at
        end
      end
    end
  end
end
