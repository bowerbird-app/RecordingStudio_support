# frozen_string_literal: true

module RecordingStudioSupport
  class InstantSearchesController < ApplicationController
    before_action :require_support_root!
    before_action :set_section_recording
    before_action -> { authorize_support!(:view) }

    def show
      @section = @section_recording.recordable
      @query = params[:q].to_s.strip
      @page_recordings = InstantPages.staff_recordings(@section_recording, query: @query)
      render layout: false
    end

    private

    def set_section_recording
      @section_recording = Sections.find_kept!(id: params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
