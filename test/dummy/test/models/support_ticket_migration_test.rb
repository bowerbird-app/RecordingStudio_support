# frozen_string_literal: true

require "test_helper"

require Rails.root.join(
  "db/migrate/20261027120000_drop_message_group_from_recording_studio_support_tickets.rb"
).to_s

class SupportTicketMigrationTest < ActiveSupport::TestCase
  TABLE = :recording_studio_support_tickets
  INDEX_NAME = "index_rs_support_tickets_on_message_group_id"

  test "migration deletes leftover rows and drops message_group_id" do
    connection.add_column TABLE, :message_group_id, :uuid unless connection.column_exists?(TABLE, :message_group_id)
    unless connection.index_exists?(TABLE, name: INDEX_NAME)
      connection.add_index TABLE, :message_group_id, unique: true, name: INDEX_NAME
    end
    connection.execute <<~SQL.squish
      INSERT INTO recording_studio_support_tickets
        (id, message_group_id, status, priority, subject, created_at, updated_at)
      VALUES
        (gen_random_uuid(), gen_random_uuid(), 'open', 'normal', 'Old ticket', NOW(), NOW())
    SQL
    assert_operator connection.select_value("SELECT COUNT(*) FROM recording_studio_support_tickets").to_i, :>=, 1

    migration.up

    refute connection.column_exists?(TABLE, :message_group_id)
    refute connection.index_exists?(TABLE, name: INDEX_NAME)
    assert_equal 0, connection.select_value("SELECT COUNT(*) FROM recording_studio_support_tickets").to_i
  ensure
    if connection.column_exists?(TABLE, :message_group_id)
      connection.remove_index TABLE, name: INDEX_NAME if connection.index_exists?(TABLE, name: INDEX_NAME)
      connection.remove_column TABLE, :message_group_id
    end
  end

  test "migration is safe when the column is already gone" do
    refute connection.column_exists?(TABLE, :message_group_id)

    migration.up

    refute connection.column_exists?(TABLE, :message_group_id)
    assert connection.column_exists?(TABLE, :subject)
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def migration
    DropMessageGroupFromRecordingStudioSupportTickets.new
  end
end
