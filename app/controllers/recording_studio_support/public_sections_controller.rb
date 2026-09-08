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
      @section_subtitle = section_subtitle_for(@section)
      @articles = Pages.public_for_section(@section_recording, query: @query).filter_map do |page|
        article_for(page)
      end
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
      redirect_to main_app.public_help_section_path(slug, **redirect_options), status: :moved_permanently
    end

    def section_subtitle_for(section)
      configured = RecordingStudioSupport.configuration.public_section_subtitle
      result = if configured.respond_to?(:call)
        configured.call(section)
      else
        configured
      end

      result.to_s.presence || "Find answers in #{section.title}."
    end

    def article_for(page)
      href = page.published_url
      return if href.blank?

      {
        title: page.title,
        href: href,
        snippet: Body.snippet(page.body),
        updated_at: page.updated_at
      }
    end
  end
end
