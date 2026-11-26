# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module CustomerVisibility
      def customer_visible_pages(actor: nil, ids: nil)
        pages = SupportPage.published
        pages = pages.where(id: ids) if ids
        action = customer_view_action
        return pages if action.blank?

        visible_ids = kept_page_recordings_for(pages).filter_map do |recording|
          recording.recordable_id if customer_visible_recording?(recording, actor: actor)
        end
        pages.where(id: visible_ids)
      end

      def customer_visible_recording?(recording, actor: nil)
        page = recording&.recordable
        return false unless page.respond_to?(:published?) && page.published?

        action = customer_view_action
        return true if action.blank?

        RecordingStudioAccessible.authorized_action?(
          actor: actor,
          action: action,
          recording: recording
        )
      end

      def customer_view_action
        return unless defined?(RecordingStudioViews)

        RecordingStudioViews.configuration.tracking_access_action
      end

      def kept_page_recordings_for(pages)
        RecordingStudio::Recording.kept.where(
          recordable_type: SUPPORT_PAGE_TYPE,
          recordable_id: pages.select(:id)
        )
      end
    end
  end
end
