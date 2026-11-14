# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    module Lookup
      module_function

      def center!(id:)
        raise_not_found("Resource was not found") if id.blank?

        SupportCenters.kept.find(id)
      rescue ActiveRecord::RecordNotFound
        raise_not_found("Resource was not found")
      end

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

      def kept_recording!(id:, not_found: "Resource was not found")
        raise_not_found(not_found) if id.blank?

        RecordingStudio::Recording.kept.find(id)
      rescue ActiveRecord::RecordNotFound
        raise_not_found(not_found)
      end

      def workspace!(id:)
        recording = kept_recording!(id: id, not_found: "Parent resource was not found")
        raise_not_found("Parent resource was not found") unless Sections.allowed_parent_root?(recording)

        recording
      end

      def parent_root!(id:)
        recording = kept_recording!(id: id, not_found: "Parent resource was not found")
        RecordingStudio.assert_parent_allowed!(child_type: Api::CENTER_TYPE, parent_recording: recording)
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
