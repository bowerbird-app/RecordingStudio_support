# frozen_string_literal: true

class AddDescriptionToRecordingStudioSupportPages < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_support_pages, :description, :text
  end
end
