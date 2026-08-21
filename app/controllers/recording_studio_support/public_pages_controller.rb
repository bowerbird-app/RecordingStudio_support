# frozen_string_literal: true

module RecordingStudioSupport
  class PublicPagesController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :set_current_actor, raise: false
    skip_before_action :require_support_root!, raise: false

    layout "recording_studio_publishable/application"

    helper RecordingStudioPublishable::ApplicationHelper if defined?(RecordingStudioPublishable::ApplicationHelper)

    def index
      @pages = Pages.public_indexable
    end

    def show
      @page = @parent_recordable
      @images = Array(@parent_recording&.try(:images))
      @published_at = @publishable&.publish_at
      record_public_view
    end

    private

    def record_public_view
      return if @parent_recording.blank?

      PageView.record!(recording: @parent_recording, actor: current_support_actor)
    end
  end
end
