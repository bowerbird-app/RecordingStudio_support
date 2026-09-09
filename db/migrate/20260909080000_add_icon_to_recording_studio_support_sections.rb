# frozen_string_literal: true

class AddIconToRecordingStudioSupportSections < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_support_sections, :icon, :string
  end
end
