# frozen_string_literal: true

module RecordingStudioSupport
  class UploadsController < ApplicationController
    before_action :require_support_root!
    before_action -> { authorize_support!(:edit) }

    ALLOWED_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
    MAX_SIZE = 10.megabytes

    def create
      file = params[:file]
      error = upload_error_for(file)
      return render json: { error: error }, status: upload_error_status(error) if error

      render json: { url: blob_url_for(store_upload(file)) }, status: :created
    end

    private

    def uploaded_file?(file)
      file.respond_to?(:original_filename) && file.respond_to?(:content_type) && file.respond_to?(:size)
    end

    def upload_error_for(file)
      return "Choose a picture." unless uploaded_file?(file)
      return "That file type is not allowed." unless ALLOWED_TYPES.include?(file.content_type)

      "That picture is too large." if file.size > MAX_SIZE
    end

    def upload_error_status(error)
      error == "Choose a picture." ? :bad_request : :unprocessable_entity
    end

    def store_upload(file)
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: file.original_filename,
        content_type: file.content_type,
        service_name: Rails.application.config.active_storage.service || :local
      )
    end

    def blob_url_for(blob)
      Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    end
  end
end
