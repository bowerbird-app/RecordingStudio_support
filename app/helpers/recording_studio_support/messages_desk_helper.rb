# frozen_string_literal: true

module RecordingStudioSupport
  module MessagesDeskHelper
    # Staff desk is mounted under /admin/support. Engine URL helpers can pick up
    # SCRIPT_NAME=/admin and generate /admin/recording_studio_messages/..., which
    # 404s. Always address the Messages mount from the app root.
    def support_messages_form_url(group_recording)
      return if group_recording.blank?

      "/recording_studio_messages/message_groups/#{group_recording.id}/messages"
    end

    def messages_inbox_href(group_recording)
      "/recording_studio_messages/message_groups/#{group_recording.id}"
    end

    # Prefer profile/display names so sidebar snippets say "Avery Admin: …"
    # instead of the email local-part ("Admin: …").
    def message_sender_name(actor)
      return "Someone" if actor.blank?

      actor_display_name(actor) || actor_email_label(actor) || actor.class.name.demodulize
    end

    def actor_display_name(actor)
      return actor.display_name.to_s.strip if actor.respond_to?(:display_name) && actor.display_name.present?
      return actor.name.to_s.strip if actor.respond_to?(:name) && actor.name.present?

      nil
    end

    def actor_email_label(actor)
      return unless actor.respond_to?(:email) && actor.email.present?

      actor.email.to_s.split("@").first.to_s.titleize
    end
  end
end
