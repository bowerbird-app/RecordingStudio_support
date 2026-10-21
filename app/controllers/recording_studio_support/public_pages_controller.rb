# frozen_string_literal: true

module RecordingStudioSupport
  class PublicPagesController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :set_current_actor, raise: false
    skip_before_action :require_support_root!, raise: false

    helper RecordingStudioPublishable::ApplicationHelper if defined?(RecordingStudioPublishable::ApplicationHelper)

    def index
      @query = params[:q].to_s.strip
      @section_recordings = Sections.public_index(query: @query)
      @page_counts = Pages.public_count_by_section(@section_recordings)
    end

    def show
      @page = @parent_recordable
      @section_recording = Pages.section_for(@parent_recording)
      @updated_at = PublicSection.article_updated_at(@page)
    end
  end
end
