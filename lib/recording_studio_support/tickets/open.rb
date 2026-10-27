# frozen_string_literal: true

module RecordingStudioSupport
  module Tickets
    # Opens a support ticket: MessageGroup under `:support`, ticket row, staff
    # grants, and the first message — one transaction.
    class Open
      def self.call(...)
        new(...).call
      end

      def initialize(actor:, subject:, body:, priority: :normal, url: nil)
        @actor = actor
        @subject = subject.to_s.strip
        @body = body.to_s
        @priority = priority
        @url = url
      end

      def call
        validate!

        SupportTicket.transaction do
          group = create_group!
          ticket = create_ticket!(group)
          post_initial_message!(group)
          ticket
        end
      end

      private

      def validate!
        raise ArgumentError, "actor is required" if @actor.blank?
        raise ArgumentError, "subject is required" if @subject.blank?
        raise ArgumentError, "body is required" if @body.blank?
      end

      def create_group!
        mount = require_mount!
        Messages::OpenAccessManagement.with { record_group!(mount) }
      end

      def require_mount!
        mount = Messages.ensure_message_mount(actor: @actor)
        return mount if mount.present?

        raise RecordingStudioMessages::Error, "Support messages are not available"
      end

      def record_group!(mount)
        group = RecordingStudioMessages.create_group(mount, title: @subject, actor: @actor)
        Messages.sync_staff_grants!(group_recording: group, manager_actor: @actor)
        group
      end

      def create_ticket!(group)
        # Vacuous when this transaction just inserted the group: no other
        # connection can see that row yet. The lock still serializes a second
        # ticket if the parent already existed.
        group.with_lock do
          raise Tickets::AlreadyExists if Tickets.ticket_recordings.exists?(parent_recording_id: group.id)

          RecordingStudio.record!(
            action: "created",
            recordable: new_ticket,
            parent_recording: group,
            root_recording: group.root_recording || group,
            actor: @actor
          ).recordable
        end
      end

      def new_ticket
        SupportTicket.new(subject: @subject, priority: @priority, status: :open)
      end

      def post_initial_message!(group)
        RecordingStudioMessages.send_message(
          group_recording: group,
          body: @body,
          actor: @actor,
          url: @url.presence || default_staff_url(group)
        )
      end

      def default_staff_url(group)
        path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
        "#{path}/messages?group_id=#{group.id}"
      end
    end
  end
end
