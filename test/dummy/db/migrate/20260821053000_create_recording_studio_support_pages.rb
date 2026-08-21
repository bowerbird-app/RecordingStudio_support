# frozen_string_literal: true

class CreateRecordingStudioSupportPages < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_support_pages, id: :uuid do |t|
      t.string :title, null: false
      t.text :body
      t.datetime :created_at, null: false
    end
  end
end
