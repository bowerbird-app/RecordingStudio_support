# frozen_string_literal: true

module RecordingStudioSupport
  class PageViewBackfill
    Result = Struct.new(:copied, :skipped, keyword_init: true)

    def self.call
      new.call
    end

    def call
      copied = 0
      skipped = 0

      PageView.find_each do |page_view|
        if already_copied?(page_view)
          skipped += 1
          next
        end

        copy!(page_view)
        copied += 1
      end

      Result.new(copied: copied, skipped: skipped)
    end

    private

    def already_copied?(page_view)
      RecordingStudioViews::ViewLog.exists?(id: page_view.id)
    end

    def copy!(page_view)
      recording = RecordingStudio::Recording.find_by(id: page_view.recording_id)
      actor = actor_for(page_view)
      attributes = HelpPageViews.attributes_for(
        recording: recording,
        occurred_at: page_view.created_at,
        actor: actor,
        id: page_view.id,
        path: help_path(recording)
      )
      attributes[:recording_id] ||= page_view.recording_id
      attributes[:actor_type] = page_view.actor_type if attributes[:actor_type].blank?
      attributes[:actor_id] = page_view.actor_id.to_s if attributes[:actor_id].blank? && page_view.actor_id.present?

      RecordingStudioViews::ViewLog.insert_all!([attributes])
    end

    def actor_for(page_view)
      type = page_view.actor_type
      id = page_view.actor_id
      return if type.blank? || id.blank?

      type.constantize.find_by(id: id)
    rescue NameError
      nil
    end

    def help_path(recording)
      recordable = recording&.recordable
      return recordable.published_url if recordable.respond_to?(:published_url) && recordable.published_url.present?

      "/"
    end
  end
end
