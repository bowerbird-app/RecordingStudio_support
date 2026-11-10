# frozen_string_literal: true

module RecordingStudioSupport
  module Tickets
    # Opens a support ticket under SupportCenter, then a tagged MessageGroup,
    # staff grants, and the first message — one transaction.
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
          ticket_recording = create_ticket!
          group = create_group!(ticket_recording)
          post_initial_message!(group)
          ticket_recording.recordable
        end
      end

      private

      def validate!
        raise ArgumentError, "actor is required" if @actor.blank?
        raise ArgumentError, "subject is required" if @subject.blank?
        raise ArgumentError, "body is required" if @body.blank?
      end

      def create_ticket!
        center = SupportCenters.current!
        RecordingStudio.record!(
          action: "created",
          recordable: new_ticket,
          parent_recording: center,
          root_recording: center.root_recording || center,
          actor: @actor
        ).recording
      end

      def create_group!(ticket_recording) # rubocop:disable Metrics/MethodLength -- lock, tag, grant, return group
        mount = require_mount!
        ticket_recording.with_lock do
          raise Tickets::AlreadyExists if tagged_group_exists?(mount, ticket_recording)

          group = Messages::OpenAccessManagement.with(actor: @actor, mount: mount) do
            RecordingStudioMessages.create_group(
              mount,
              title: @subject,
              actor: @actor,
              tags: { Tickets::TAG_KEY => ticket_recording }
            )
          end
          Messages.sync_staff_grants!(group_recording: group, manager_actor: @actor)
          group
        end
      end

      def tagged_group_exists?(mount, ticket_recording)
        RecordingStudioMessages.tagged_group_recordings(
          mount_recording: mount,
          tags: { Tickets::TAG_KEY => ticket_recording }
        ).exists?
      end

      def require_mount!
        mount = Messages.ensure_message_mount(actor: @actor)
        return mount if mount.present?

        raise RecordingStudioMessages::Error, "Support messages are not available"
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
