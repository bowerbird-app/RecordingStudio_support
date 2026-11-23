# frozen_string_literal: true

module RecordingStudioSupport
  module McpCopy
    module TypeDescriptions
      CENTER =
        "A SupportCenter is the bucket for help articles and tickets. Sections, pages, and " \
        "tickets sit under it. Create it under the host parent root. Pass that parent recording " \
        "id as parent_id. If more than one SupportCenter exists, ask which one to use. Do not " \
        "pick a default."

      SECTION =
        "A SupportSection groups help pages under a SupportCenter. Create it under a " \
        "SupportCenter and pass that center's recording id as parent_id."

      PAGE =
        "A SupportPage is a help article with a title and body. Create it under a SupportSection " \
        "and pass that section's recording id as parent_id. Publish it so people can read it."

      TICKET =
        "A SupportTicket is a signed-in help request. open_support_ticket creates the ticket, " \
        "a tagged conversation, and the first message. Later replies use reply_to_support_ticket " \
        "with this ticket's recording id. Tickets no longer store a message group id; the " \
        "conversation is the group tagged support_ticket on this ticket."

      BY_TYPE = {
        "RecordingStudioSupport::SupportCenter" => CENTER,
        "RecordingStudioSupport::SupportSection" => SECTION,
        "RecordingStudioSupport::SupportPage" => PAGE,
        "RecordingStudioSupport::SupportTicket" => TICKET
      }.freeze
    end
  end
end
