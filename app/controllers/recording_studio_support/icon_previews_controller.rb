# frozen_string_literal: true

module RecordingStudioSupport
  class IconPreviewsController < ApplicationController
    before_action :require_support_root!
    before_action -> { authorize_support!(:edit) }

    def show
      @icon_name = params[:name]
      render layout: false
    end
  end
end
