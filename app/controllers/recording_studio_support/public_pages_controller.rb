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
    end

    def show
      @page = @parent_recordable
      @images = Array(@parent_recording&.try(:images))
      @published_at = @publishable&.publish_at
      @section_recording = Pages.section_for(@parent_recording)
      record_public_view
    end

    private

    def record_public_view
      return if @parent_recording.blank?

      PageView.record!(recording: @parent_recording, actor: current_support_actor)
    end
  end
end
