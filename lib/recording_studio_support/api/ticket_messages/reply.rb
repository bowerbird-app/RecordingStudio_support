# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module TicketMessages
      class Reply
        def self.call(context)
          new(context).call
        end

        def initialize(context)
          @context = context
        end

        def call
          TicketMessages.authorize!(@context)
          group = TicketMessages.conversation!(@context)
          message = TicketMessages.wrap_messages_error { post!(group) }
          TicketMessages.serialize_message(message)
        end

        private

        def post!(group)
          RecordingStudioMessages.send_message(
            group_recording: group,
            body: body,
            actor: TicketAccess.actor(@context),
            url: default_url(group)
          )
        end

        def body
          params = @context.params
          (params[:body].presence || params["body"].presence).to_s
        end

        def default_url(group)
          path = RecordingStudioSupport.configuration.pages_path.to_s.chomp("/")
          "#{path}/messages?group_id=#{group.id}"
        end
      end
    end
  end
end
