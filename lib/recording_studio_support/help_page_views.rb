# frozen_string_literal: true

require "securerandom"

module RecordingStudioSupport
  module HelpPageViews
    RESOURCE_TYPE = "RecordingStudioSupport::SupportPage"
    PAGE_KEY = "recording"

    module_function

    def relation
      RecordingStudioViews::ViewLog.where(resource_type: RESOURCE_TYPE)
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength -- ViewLog columns in one insert hash
    def attributes_for(recording:, occurred_at:, actor: nil, id: nil, path: "/")
      at = occurred_at.utc
      {
        id: id || SecureRandom.uuid,
        occurred_at: at,
        arrived_at: at,
        created_at: at,
        updated_at: at,
        root_recording_id: recording&.root_recording_id.presence || recording&.id,
        recording_id: recording&.id,
        resource_type: RESOURCE_TYPE,
        page_key: PAGE_KEY,
        path: path.to_s.presence || "/",
        actor_type: actor&.class&.name,
        actor_id: actor&.id&.to_s
      }
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength
  end
end
