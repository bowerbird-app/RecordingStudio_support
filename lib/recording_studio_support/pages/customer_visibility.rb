# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module CustomerVisibility
      def customer_visible_pages(actor: nil)
        pages = SupportPage.published
        return pages unless customer_view_configured?

        ids = kept_page_recordings_for(pages).filter_map do |recording|
          recording.recordable_id if customer_visible_recording?(recording, actor: actor)
        end
        pages.where(id: ids)
      end

      def customer_visible_recording?(recording, actor: nil)
        page = recording&.recordable
        return false unless page.respond_to?(:published?) && page.published?
        return true unless customer_view_configured?

        RecordingStudioAccessible::AudienceAuthorization.authorized?(
          actor: actor,
          action: CUSTOMER_VIEW_ACTION,
          recording: recording
        )
      end

      def customer_view_configured?
        defined?(RecordingStudioAccessible::AudienceResolver) &&
          RecordingStudioAccessible::AudienceResolver.configured?(CUSTOMER_VIEW_ACTION)
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
