# frozen_string_literal: true

require_relative "tickets/open"
require_relative "tickets/update"

module RecordingStudioSupport
  # Support tickets wrap a MessageGroup under the Workspace `:support` mount.
  # Tickets own conversation lifecycle; MessageGroups are created per ticket.
  module Tickets
    TICKET_TYPE = "RecordingStudioSupport::SupportTicket"
    UNSET = Copy::UNSET
    CURRENT_JOIN = <<~SQL.squish.freeze
      INNER JOIN recording_studio_recordings
        ON recording_studio_recordings.recordable_id = recording_studio_support_tickets.id
       AND recording_studio_recordings.recordable_type = '#{TICKET_TYPE}'
       AND recording_studio_recordings.trashed_at IS NULL
    SQL

    class AlreadyExists < StandardError
      def message
        Copy.t("messages.already_open")
      end
    end

    module_function

    def open!(...)
      Open.call(...)
    end

    def find!(id)
      recording = ticket_recordings.find_by(id: id) || recording_for_ticket_id!(id)
      recording.recordable
    end

    def update!(...)
      Update.call(...)
    end

    def current
      current_relation(SupportTicket.all)
    end

    def current_relation(relation)
      relation.joins(CURRENT_JOIN)
    end

    def for_message_group_ids(message_group_ids)
      ids = Array(message_group_ids).compact
      return SupportTicket.none if ids.empty?

      SupportTicket.where(id: ticket_recordings.where(parent_recording_id: ids).select(:recordable_id))
                   .order(created_at: :desc)
    end

    def tickets_by_group_id(message_group_ids)
      ids = Array(message_group_ids).compact
      return {} if ids.empty?

      ticket_recordings.where(parent_recording_id: ids).includes(:recordable).each_with_object({}) do |recording, map|
        map[recording.parent_recording_id] = recording.recordable
      end
    end

    def group_recording_for(ticket)
      return if ticket.blank?
      return unless ticket.respond_to?(:id)
      return if ticket.id.blank?

      recording = ticket_recordings.find_by(recordable_id: ticket.id) || recording_for_snapshot_id(ticket.id)
      recording&.parent_recording
    end

    def ticket_recordings
      RecordingStudio::Recording.where(recordable_type: TICKET_TYPE, trashed_at: nil)
    end

    def recording_for!(ticket)
      recording_for_ticket_id!(ticket.id)
    end

    def recording_for_ticket_id!(id)
      recording = ticket_recordings.find_by(recordable_id: id)
      recording ||= recording_for_snapshot_id(id)
      raise ActiveRecord::RecordNotFound if recording.blank?

      recording
    end

    def recording_for_snapshot_id(id)
      event = RecordingStudio::Event.where(recordable_type: TICKET_TYPE, recordable_id: id)
                                    .or(RecordingStudio::Event.where(previous_recordable_type: TICKET_TYPE,
                                                                     previous_recordable_id: id))
                                    .order(occurred_at: :desc)
                                    .first
      return if event.blank?

      ticket_recordings.find_by(id: event.recording_id)
    end

    def for_actor(actor)
      return SupportTicket.none if actor.blank?

      group_ids = owned_group_recording_ids(actor)
      return SupportTicket.none if group_ids.empty?

      for_message_group_ids(group_ids)
    end

    def owned_group_recording_ids(actor)
      mount = Messages.ensure_message_mount(actor: actor)
      return [] if mount.blank?

      RecordingStudioMessages.viewable_group_recordings(
        actor: actor,
        mount_recording: mount
      ).filter_map do |group|
        group.id if Messages.group_owner?(group, actor)
      end
    end
  end
end
