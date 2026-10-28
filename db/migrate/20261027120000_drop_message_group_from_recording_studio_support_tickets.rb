# frozen_string_literal: true

class DropMessageGroupFromRecordingStudioSupportTickets < ActiveRecord::Migration[8.1]
  TABLE = :recording_studio_support_tickets
  INDEX_NAME = "index_rs_support_tickets_on_message_group_id"

  # Existing ticket rows are unused. Delete them, then drop the group column.
  def up
    return unless table_exists?(TABLE)
    return unless column_exists?(TABLE, :message_group_id)

    execute "DELETE FROM #{quote_table_name(TABLE)}"
    remove_index TABLE, name: INDEX_NAME if index_exists?(TABLE, name: INDEX_NAME)
    remove_column TABLE, :message_group_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "deleted ticket rows and message_group_id cannot be restored"
  end
end
