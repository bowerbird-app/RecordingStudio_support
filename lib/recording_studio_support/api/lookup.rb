# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Lookup
      module_function

      def page!(id:, include_trashed: false)
        raise_not_found("Resource was not found") if id.blank?

        finder = include_trashed ? Pages.method(:find!) : Pages.method(:find_kept!)
        finder.call(id: id)
      rescue ActiveRecord::RecordNotFound
        raise_not_found("Resource was not found")
      end

      def section!(id:, include_trashed: false)
        raise_not_found("Resource was not found") if id.blank?

        finder = include_trashed ? Sections.method(:find!) : Sections.method(:find_kept!)
        finder.call(id: id)
      rescue ActiveRecord::RecordNotFound
        raise_not_found("Resource was not found")
      end

      def workspace!(id:)
        raise_not_found("Parent resource was not found") if id.blank?

        recording = RecordingStudio::Recording.where(trashed_at: nil).find(id)
        raise_not_found("Parent resource was not found") unless Sections.allowed_parent_root?(recording)

        recording
      rescue ActiveRecord::RecordNotFound
        raise_not_found("Parent resource was not found")
      end

      def page_in_section!(section:, id:, include_trashed: false)
        page = page!(id: id, include_trashed: include_trashed)
        return page if page.parent_recording_id.to_s == section.id.to_s

        raise_not_found("Relationship resource was not found")
      end

      def raise_not_found(message)
        raise RecordingStudioApi::NotFoundError, message
      end
    end
  end
end
