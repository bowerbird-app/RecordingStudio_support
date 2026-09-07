# frozen_string_literal: true

module RecordingStudioSupport
  class PublicSectionsController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :set_current_actor, raise: false
    skip_before_action :require_support_root!, raise: false

    def show
      key = params[:slug].presence || params[:id]
      @section_recording = resolve_public_section!(key)
      return if performed?

      @section = @section_recording.recordable
      @query = params[:q].to_s.strip
      @pages = Pages.public_for_section(@section_recording, query: @query)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def resolve_public_section!(key)
      if Sections.public_key_uuid?(key)
        recording = Sections.find_kept!(id: key)
        redirect_uuid_bookmark!(recording, key)
        return recording
      end

      Sections.find_kept_by_slug!(slug: key)
    end

    def redirect_uuid_bookmark!(recording, key)
      slug = recording.recordable&.slug
      return if slug.blank?
      return if key.to_s == slug

      redirect_options = {}
      redirect_options[:q] = params[:q] if params[:q].present?
      redirect_to support_public_section_path(recording, **redirect_options), status: :moved_permanently
    end
  end
end
