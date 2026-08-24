# frozen_string_literal: true

module RecordingStudioSupport
  class PagesController < ApplicationController
    before_action :require_support_root!
    before_action -> { authorize_support!(:view) }, only: %i[index show]
    before_action -> { authorize_support!(:edit) }, only: %i[new create edit update trash]
    before_action :set_page_recording, only: %i[show edit update trash]

    def index
      @query = params[:q].to_s.strip
      @page_recordings = Pages.for_root(current_support_root_recording, query: @query)
    end

    def show
      PageView.record!(recording: @page_recording, actor: current_support_actor)
      @page = @page_recording.recordable
      @images = @page_recording.images.to_a
    end

    def new
      @page = SupportPage.new
    end

    def create
      @page_recording = Pages.create!(
        root_recording: current_support_root_recording,
        **page_write_attrs
      )
      redirect_to page_path(@page_recording), notice: "Saved. That should help someone."
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
      redirect_to pages_path, notice: "That page is in the trash."
    end

    private

    def set_page_recording
      @page_recording = Pages.find_for_root!(
        root_recording: current_support_root_recording,
        id: params[:id]
      )
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def page_params
      params.fetch(:page, {}).permit(:title, :body)
    end

    def page_write_attrs
      {
        title: page_params[:title],
        body: page_params[:body],
        actor: current_support_actor
      }
    end

    def render_invalid_page(error, template:)
      @page = error.record
      flash.now[:alert] = "Couldn't save that page. Give it a title and try again."
      render template, status: :unprocessable_entity
    end
  end
end
