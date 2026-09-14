# frozen_string_literal: true

module RecordingStudioSupport
  class PublicInstantSearchesController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :set_current_actor, raise: false
    skip_before_action :require_support_root!, raise: false

    def show
      key = params[:slug].presence || params[:id]
      @section_recording = resolve_public_section!(key)
      return if performed?

      @section = @section_recording.recordable
      @query = params[:q].to_s.strip
      @articles = InstantPages.public_articles(@section_recording, query: @query)
      render layout: false
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def resolve_public_section!(key)
      return Sections.find_kept!(id: key) if Sections.public_key_uuid?(key)

      Sections.find_kept_by_slug!(slug: key)
    end
  end
end
