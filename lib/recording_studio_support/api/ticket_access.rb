# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketAccess
      module_function

      def authorize_view!(context)
        scope = context.access_grant.scope_recording
        Access.deny! if scope.blank?

        context.access_grant.authorize!(recording: scope, role: :view)
      end

      def authorize_support_team!(context)
        center = SupportCenters.current
        Access.deny! if center.blank?

        context.access_grant.authorize!(recording: center, role: :edit)
      end

      def actor(context)
        Access.actor_for(context)
      end

      def recordings_for(context)
        tickets = Tickets.current
        tickets = tickets.merge(Tickets.for_actor(actor(context))) unless Access.operations_api?(context)
        Tickets.ticket_recordings.where(recordable_id: tickets.select(:id))
      end

      def find_recording!(context)
        ticket = Tickets.find!(Payload.member_id(context))
        recording = Tickets.recording_for!(ticket)
        return recording if Access.operations_api?(context)
        return recording if visible_to_actor?(context, ticket)

        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope"
      rescue ActiveRecord::RecordNotFound
        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope"
      end

      def visible_to_actor?(context, ticket)
        person = actor(context)
        return false if person.blank?
        return true if Messages.support_team_actor?(person)

        Tickets.for_actor(person).exists?(id: ticket.id)
      end

      def invalid_input!(error)
        raise RecordingStudioApi::InvalidActionInputError.new(
          error.message,
          details: input_details(error)
        )
      end

      def input_details(error)
        record = error.respond_to?(:record) ? error.record : nil
        return [] if record.blank? || !record.respond_to?(:errors)

        record.errors.map do |item|
          {
            attribute: item.attribute,
            message: item.message,
            full_message: item.full_message,
            type: item.type
          }
        end
      end
    end
  end
end
