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
  end
end
