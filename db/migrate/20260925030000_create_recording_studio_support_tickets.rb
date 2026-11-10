# frozen_string_literal: true

class CreateRecordingStudioSupportTickets < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength -- ticket columns and indexes in one create_table
    create_table :recording_studio_support_tickets, id: :uuid do |t|
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "normal"
      t.string :subject, null: false
      t.string :assignee_type
      t.uuid :assignee_id
      t.datetime :resolved_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index :status, name: "index_rs_support_tickets_on_status"
      t.index %i[assignee_type assignee_id], name: "index_rs_support_tickets_on_assignee"
    end
  end
end
