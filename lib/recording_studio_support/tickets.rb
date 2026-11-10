# frozen_string_literal: true

require_relative "tickets/open"
require_relative "tickets/update"

module RecordingStudioSupport
  # Support tickets live under SupportCenter. The conversation is a tagged
  # MessageGroup on the :support mount, not a parent.
  module Tickets # rubocop:disable Metrics/ModuleLength -- public ticket API and tag lookups stay together
    TICKET_TYPE = "RecordingStudioSupport::SupportTicket"
    TAG_KEY = "support_ticket"
    UNSET = Copy::UNSET

    class AlreadyExists < StandardError
      def message
        Copy.t(
          "messages.already_open",
          default: "This conversation already has a ticket."
        )
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
      relation.joins(current_join_sql)
    end

    def current_join_sql
      connection = ActiveRecord::Base.connection
      recordings = RecordingStudio::Recording.table_name
      quoted_recordings = connection.quote_table_name(recordings)
      quoted_tickets = connection.quote_table_name(SupportTicket.table_name)
      type = connection.quote(TICKET_TYPE)
      kept = RecordingStudio::Recording.recording_studio_trashable_kept_sql(recordings)
      "INNER JOIN #{quoted_recordings} ON #{quoted_recordings}.recordable_id = #{quoted_tickets}.id " \
        "AND #{quoted_recordings}.recordable_type = #{type} AND #{kept}"
    end

    def for_message_group_ids(message_group_ids)
      ids = Array(message_group_ids).compact
      return SupportTicket.none if ids.empty?

      ticket_ids = tagged_ticket_recordings(ids).map(&:recordable_id)
      SupportTicket.where(id: ticket_ids).order(created_at: :desc)
    end

    def tickets_by_group_id(message_group_ids)
      ids = Array(message_group_ids).compact
      return {} if ids.empty?

      tagged_ticket_recordings(ids).each_with_object({}) do |ticket_recording, map|
        group_id = group_id_for_ticket_recording(ticket_recording)
        next if group_id.blank?

        map[group_id] = ticket_recording.recordable
      end
    end

    def group_recording_for(ticket)
      recording = ticket_recording_for(ticket)
      return if recording.blank?

      mount = Messages.ensure_message_mount
      return if mount.blank?

      RecordingStudioMessages.tagged_group_recordings(
        mount_recording: mount,
        tags: { TAG_KEY => recording }
      ).first
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

      group_ids = viewable_group_recording_ids(actor)
      return SupportTicket.none if group_ids.empty?

      for_message_group_ids(group_ids)
    end

    def viewable_group_recording_ids(actor) # rubocop:disable Metrics/MethodLength -- mount then tag filter
      mount = Messages.ensure_message_mount(actor: actor)
      return [] if mount.blank?

      group_ids = RecordingStudioMessages.viewable_group_recordings(
        actor: actor,
        mount_recording: mount
      ).map(&:id)
      return [] if group_ids.empty?

      RecordingStudioMessages::MessageGroupTag.where(
        key: TAG_KEY,
        message_group_recording_id: group_ids
      ).pluck(:message_group_recording_id)
    end

    def ticket_recording_for(ticket)
      return if ticket.blank?
      return unless ticket.respond_to?(:id)
      return if ticket.id.blank?

      ticket_recordings.find_by(recordable_id: ticket.id) || recording_for_snapshot_id(ticket.id)
    end

    def tagged_ticket_recordings(group_ids)
      tag_rows = RecordingStudioMessages::MessageGroupTag.where(
        key: TAG_KEY,
        message_group_recording_id: group_ids
      )
      ticket_recordings.where(id: tag_rows.select(:tagged_recording_id)).includes(:recordable)
    end

    def group_id_for_ticket_recording(ticket_recording)
      RecordingStudioMessages::MessageGroupTag.find_by(
        key: TAG_KEY,
        tagged_recording_id: ticket_recording.id
      )&.message_group_recording_id
    end
  end
end
