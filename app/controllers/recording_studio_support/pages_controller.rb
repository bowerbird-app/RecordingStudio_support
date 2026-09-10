# frozen_string_literal: true

module RecordingStudioSupport
  class PagesController < ApplicationController
    before_action :require_support_root!
    before_action :set_page_recording, only: %i[show edit update trash]
    before_action :set_page_parent_section_for_authorization, only: %i[new create]
    before_action -> { authorize_support!(:view) }, only: %i[show]
    before_action -> { authorize_support!(:edit) }, only: %i[new create edit update trash]
    before_action :load_section_choices, only: %i[new create]

    def show
      PageView.record!(recording: @page_recording, actor: current_support_actor)
      @page = @page_recording.recordable
      @section_recording = Pages.section_for(@page_recording)
    end

    def new
      @page = SupportPage.new
      @selected_section_id = params[:section_id].presence || @section_choices.first&.id
      apply_default_page_icon_from_section!
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
      @section_recording = Pages.section_for(@page_recording)
      apply_default_page_icon_from_section!
    end

    def update
      Pages.revise!(recording: @page_recording, **page_write_attrs)
      redirect_to page_path(@page_recording), notice: "Updated. Nice catch."
    rescue ActiveRecord::RecordInvalid => e
      render_invalid_page(e, template: :edit)
    end

    def trash
      Pages.trash!(recording: @page_recording, actor: current_support_actor)
      redirect_to RecordingStudioSupport::Admin::Queries.admin_pages_screen_path,
                  notice: "That page is in the trash."
    end

    private

    def set_page_recording
      @page_recording = Pages.find_kept!(id: params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_page_parent_section_for_authorization
      @section_recording = page_parent_section_recording
    end

    def load_section_choices
      @section_choices = Sections.for_root(current_support_root_recording)
    end

    def page_params
      params.fetch(:page, {}).permit(:title, :description, :body, :icon, :section_id)
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
        description: page_params[:description],
        body: page_params[:body],
        icon: page_params[:icon],
        actor: current_support_actor
      }
    end

    def apply_default_page_icon_from_section!
      return if @page.icon.present?

      section = page_icon_source_section
      return if section.blank?

      @page.icon = section.icon
    end

    def page_icon_source_section
      recording = @section_recording
      recording ||= @section_choices&.find { |choice| choice.id.to_s == @selected_section_id.to_s }
      recording&.recordable
    end

    def render_missing_section
      @page = SupportPage.new(
        title: page_params[:title],
        description: page_params[:description],
        body: page_params[:body],
        icon: page_params[:icon]
      )
      flash.now[:alert] = "Add a section first, then you can write a page."
      render :new, status: :unprocessable_entity
    end

    def render_invalid_page(error, template:)
      @page = error.record
      @selected_section_id = page_params[:section_id]
      @section_recording = Pages.section_for(@page_recording) if @page_recording
      flash.now[:alert] = "Couldn't save that page. Give it a title and try again."
      render template, status: :unprocessable_entity
    end
  end
end
