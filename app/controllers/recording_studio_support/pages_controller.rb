# frozen_string_literal: true

module RecordingStudioSupport
  class PagesController < ApplicationController
    before_action :require_support_root!
    before_action -> { authorize_support!(:view) }, only: %i[show]
    before_action -> { authorize_support!(:edit) }, only: %i[new create edit update trash]
    before_action :set_page_recording, only: %i[show edit update trash]
    before_action :load_section_choices, only: %i[new create]

    def show
      PageView.record!(recording: @page_recording, actor: current_support_actor)
      @page = @page_recording.recordable
      @section_recording = Pages.section_for(@page_recording)
      @images = @page_recording.images.to_a
    end

    def new
      @page = SupportPage.new
      @selected_section_id = params[:section_id].presence || @section_choices.first&.id
    end

    def create
      section = page_parent_section_recording
      return render_missing_section if section.blank?

      create_page!(section)
    rescue ActiveRecord::RecordInvalid => e
      render_invalid_page(e, template: :new)
    end

    def edit
      @page = @page_recording.recordable
    end

    def update
      Pages.revise!(recording: @page_recording, **page_write_attrs)
      redirect_to page_path(@page_recording), notice: "Updated. Nice catch."
    rescue ActiveRecord::RecordInvalid => e
      render_invalid_page(e, template: :edit)
    end

    def trash
      Pages.trash!(recording: @page_recording, actor: current_support_actor)
      redirect_to root_path, notice: "That page is in the trash."
    end

    private

    def set_page_recording
      @page_recording = Pages.find_kept!(id: params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_section_choices
      @section_choices = Sections.for_root(current_support_root_recording)
    end

    def page_params
      params.fetch(:page, {}).permit(:title, :body, :section_id)
    end

    def create_page!(section)
      @page_recording = Pages.create!(
        parent_recording: section,
        **page_write_attrs
      )
      redirect_to page_path(@page_recording), notice: "Saved. That should help someone."
    end

    def page_write_attrs
      {
        title: page_params[:title],
        body: page_params[:body],
        actor: current_support_actor
      }
    end

    def render_missing_section
      @page = SupportPage.new(title: page_params[:title], body: page_params[:body])
      flash.now[:alert] = "Add a section first, then you can write a page."
      render :new, status: :unprocessable_entity
    end

    def render_invalid_page(error, template:)
      @page = error.record
      @selected_section_id = page_params[:section_id]
      flash.now[:alert] = "Couldn't save that page. Give it a title and try again."
      render template, status: :unprocessable_entity
    end
  end
end
