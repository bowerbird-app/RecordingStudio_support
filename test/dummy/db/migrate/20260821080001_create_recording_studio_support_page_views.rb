# frozen_string_literal: true

class CreateRecordingStudioSupportPageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_support_page_views, id: :uuid do |t|
      t.uuid :recording_id, null: false
      t.string :actor_type
      t.uuid :actor_id
      t.datetime :created_at, null: false
    end

    add_index :recording_studio_support_page_views, :recording_id
    add_index :recording_studio_support_page_views, :created_at
  end
end
