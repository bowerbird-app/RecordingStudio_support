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
        mount = Messages.ensure_message_mount(actor: @actor)
        raise RecordingStudioMessages::Error, "Support messages are not available" if mount.blank?

        Messages::OpenAccessManagement.with do
          group = RecordingStudioMessages.create_group(
            mount,
            title: @subject,
            actor: @actor
          )
          Messages.sync_staff_grants!(
            group_recording: group,
            manager_actor: @actor
          )
          group
        end
      end

      def create_ticket!(group)
        SupportTicket.create!(
          message_group_id: group.id,
          subject: @subject,
          priority: @priority,
          status: :open
        )
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
