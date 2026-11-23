# frozen_string_literal: true

module RecordingStudioSupport
  module McpCopy
    module OperationDescriptions
      CREATE_NOTES = {
        "RecordingStudioSupport::SupportCenter" =>
          "Pass parent_id as the host parent-root recording id. A SupportCenter has no extra writable fields.",
        "RecordingStudioSupport::SupportSection" =>
          "Pass parent_id as the SupportCenter recording id from list_support_centers or show_support_center. " \
          "Send title at the root, not nested under attributes. icon is optional.",
        "RecordingStudioSupport::SupportPage" =>
          "Pass parent_id as the SupportSection recording id from list_support_sections. " \
          "Send title at the root, not nested under attributes. body, description, and icon are optional. " \
          "Publish with publish_support_page so people can read it.",
        "RecordingStudioSupport::SupportTicket" =>
          "Pass subject and body at the root, not nested under attributes. body is the first message. " \
          "priority is optional (low, normal, or high). This also creates the conversation and posts " \
          "that first message. Later replies use reply_to_support_ticket."
      }.freeze

      UPDATE_NOTES = {
        "RecordingStudioSupport::SupportSection" =>
          "Pass the section recording id. Send title or icon at the root, not nested under attributes.",
        "RecordingStudioSupport::SupportPage" =>
          "Pass the page recording id. Send title, description, icon, or body at the root, not nested " \
          "under attributes. Publishing is publish_support_page, not this tool.",
        "RecordingStudioSupport::SupportTicket" =>
          "Pass the ticket recording id. Send status (open or resolved) and/or priority (low, normal, " \
          "or high) at the root, not nested under attributes. Replies use reply_to_support_ticket."
      }.freeze

      INDEX_NOTES = {
        "RecordingStudioSupport::SupportPage" =>
          "root_id on a record is the workspace, not the parent. For published pages by title and body, " \
          "use search_support_pages.",
        "RecordingStudioSupport::SupportTicket" =>
          "Use show_support_ticket for one ticket. Messages are list_support_ticket_messages with this " \
          "ticket's recording id."
      }.freeze
      PAGE_LEADS = {
        move:
          "Moves a support page to another SupportSection. Pass the page recording id and parent_id " \
          "as the destination section recording id from list_support_sections.",
        publish:
          "Publishes a support page so people can read it. Pass the page recording id. The page must " \
          "already exist. Create it first with create_support_page.",
        unpublish:
          "Unpublishes a support page. Pass the page recording id. The page must already exist."
      }.freeze
      PAGE_OUTPUTS = {
        move: "The support page after the move.",
        publish: "The support page after publish.",
        unpublish: "The support page after unpublish."
      }.freeze

      module_function

      def title_for(type, verb)
        return "Open support ticket" if type.to_s == Api::TICKET_TYPE && verb.to_sym == :create

        Api::OperationDocs.operation_title(type, verb) || Api::OperationDocs.capability_title(type, verb)
      end

      def description_for(type, verb)
        [lead_for(type, verb), note_for(type, verb), TypeDescriptions::BY_TYPE.fetch(type.to_s)]
          .compact.join(" ")
      end

      def output_for(type, verb)
        PAGE_OUTPUTS[verb.to_sym] || output_for_noun(noun_for(type), verb)
      end

      def lead_for(type, verb)
        return PAGE_LEADS[verb.to_sym] if PAGE_LEADS.key?(verb.to_sym)
        return "Opens a support ticket." if verb.to_sym == :create && type.to_s == Api::TICKET_TYPE

        lead_for_noun(noun_for(type), verb)
      end

      def output_for_noun(noun, verb)
        {
          index: "The matching #{noun.pluralize}.",
          show: "The #{noun}.",
          create: "The new #{noun}.",
          update: "The #{noun} after the change."
        }.fetch(verb.to_sym, "The #{noun}.")
      end

      def lead_for_noun(noun, verb)
        {
          index: "Lists #{noun.pluralize}.",
          show: "Shows one #{noun} by recording id.",
          create: "Creates a #{noun}.",
          update: "Updates a #{noun}. Pass its recording id."
        }.fetch(verb.to_sym, "#{verb} a #{noun}.")
      end

      def note_for(type, verb)
        case verb.to_sym
        when :create then CREATE_NOTES[type.to_s]
        when :update then UPDATE_NOTES[type.to_s]
        when :index then INDEX_NOTES[type.to_s]
        end
      end

      def noun_for(type)
        type.to_s.split("::").last.underscore.tr("_", " ")
      end
    end
  end
end
