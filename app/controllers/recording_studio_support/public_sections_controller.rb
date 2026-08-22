# frozen_string_literal: true

module RecordingStudioSupport
  class PublicSectionsController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :set_current_actor, raise: false
    skip_before_action :require_support_root!, raise: false

    def show
      @section_recording = Sections.find_kept!(id: params[:id])
      @section = @section_recording.recordable
      @query = params[:q].to_s.strip
      @pages = Pages.public_for_section(@section_recording, query: @query)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
