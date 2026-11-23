# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketMessages
      class UnreadCount
        def self.call(context)
          new(context).call
        end

        def initialize(context)
          @context = context
        end

        def call
          TicketMessages.authorize!(@context)
          actor = TicketAccess.actor(@context)
          Access.deny! if actor.blank?

          { unread_count: unread_ids(actor).size }
        end

        private

        def unread_ids(actor)
          listed = listed_group_ids(actor)
          return [] if listed.empty?

          mount = Messages.ensure_message_mount(actor: actor)
          return [] if mount.blank?

          unread = RecordingStudioMessages.viewable_group_recordings(
            actor: actor,
            mount_recording: mount,
            unread: true
          ).map(&:id)
          unread & listed
        end

        def listed_group_ids(actor)
          tickets = if Access.operations_api?(@context)
                      Tickets.current
                    else
                      Tickets.for_actor(actor)
                    end
          tickets.filter_map { |ticket| Tickets.group_recording_for(ticket)&.id }
        end
      end
    end
  end
end
