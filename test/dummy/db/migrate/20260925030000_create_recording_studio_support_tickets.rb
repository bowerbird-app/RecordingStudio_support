# frozen_string_literal: true

class CreateRecordingStudioSupportTickets < ActiveRecord::Migration[8.1]
  # Ticket columns and indexes stay together for a single install step.
  def change # rubocop:disable Metrics/MethodLength
    create_table :recording_studio_support_tickets, id: :uuid do |t|
      t.uuid :message_group_id, null: false
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "normal"
      t.string :subject, null: false
      t.string :assignee_type
      t.uuid :assignee_id
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :recording_studio_support_tickets, :message_group_id,
              unique: true, name: "index_rs_support_tickets_on_message_group_id"
    add_index :recording_studio_support_tickets, :status,
              name: "index_rs_support_tickets_on_status"
    add_index :recording_studio_support_tickets, %i[assignee_type assignee_id],
              name: "index_rs_support_tickets_on_assignee"
  end
end
