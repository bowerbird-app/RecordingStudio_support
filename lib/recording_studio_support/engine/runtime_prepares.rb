# frozen_string_literal: true

module RecordingStudioSupport
  class Engine < ::Rails::Engine
    initializer "recording_studio_support.page_nav_compat" do
      config.to_prepare do
        page_nav = FlatPack::PageNav::Component if defined?(FlatPack::PageNav::Component)
        page_nav&.prepend(PageNavCompat) unless page_nav&.ancestors&.include?(PageNavCompat)
        search = defined?(RecordingStudioSearch::InstantSearchesController) &&
                 RecordingStudioSearch::InstantSearchesController
        search&.prepend(SearchInstantLivePages) unless search&.ancestors&.include?(SearchInstantLivePages)
      end
    end
  end
end
