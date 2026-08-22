# frozen_string_literal: true

module RecordingStudioSupport
  class SectionsController < ApplicationController
    before_action :require_support_root!
    before_action -> { authorize_support!(:view) }, only: %i[index show]
    before_action -> { authorize_support!(:edit) }, only: %i[new create edit update trash]
    before_action :set_section_recording, only: %i[show edit update trash]

    def index
      @query = params[:q].to_s.strip
      @section_recordings = Sections.for_root(current_support_root_recording, query: @query)
      @page_counts = Pages.kept_count_by_section(@section_recordings)
    end

    def show
      @section = @section_recording.recordable
      @query = params[:q].to_s.strip
      @page_recordings = Pages.for_section(@section_recording, query: @query)
    end

    def new
      @section = SupportSection.new
    end

    def create
      @section_recording = Sections.create!(
        root_recording: section_parent_root_recording,
        title: section_params[:title],
        actor: current_support_actor
      )
      redirect_to section_path(@section_recording), notice: "Section ready. Add a page when you are."
    rescue ActiveRecord::RecordInvalid => e
      render_invalid_section(e, template: :new)
    end

    def edit
      @section = @section_recording.recordable
    end

    def update
      Sections.revise!(
        recording: @section_recording,
        title: section_params[:title],
        actor: current_support_actor
      )
      redirect_to section_path(@section_recording), notice: "Section name updated."
    rescue ActiveRecord::RecordInvalid => e
      render_invalid_section(e, template: :edit)
    end

    def trash
      Sections.trash!(recording: @section_recording, actor: current_support_actor)
      redirect_to root_path, notice: "That section is in the trash, pages and all."
    end

    private

    def set_section_recording
      @section_recording = Sections.find_kept!(id: params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def section_params
      params.fetch(:section, {}).permit(:title)
    end

    def render_invalid_section(error, template:)
      @section = error.record
      flash.now[:alert] = "Couldn't save that section. Give it a name and try again."
      render template, status: :unprocessable_entity
    end
  end
end
