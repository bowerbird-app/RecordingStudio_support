# frozen_string_literal: true

class AddIconToRecordingStudioSupportPages < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_support_pages, :icon, :string
  end
end
