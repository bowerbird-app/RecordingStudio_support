# frozen_string_literal: true

require "test_helper"

class SupportTicketMigrationTest < ActiveSupport::TestCase
  test "tickets table has no message_group_id" do
    refute connection.column_exists?(:recording_studio_support_tickets, :message_group_id)
    assert connection.column_exists?(:recording_studio_support_tickets, :subject)
    assert connection.column_exists?(:recording_studio_support_tickets, :status)
    assert connection.column_exists?(:recording_studio_support_tickets, :priority)
    names = connection.columns(:recording_studio_support_tickets).map(&:name)
    assert_equal %w[created_at id priority resolved_at status subject updated_at], names.sort
  end

  test "support centers table exists" do
    assert connection.table_exists?(:recording_studio_support_centers)
    assert connection.column_exists?(:recording_studio_support_centers, :created_at)
  end

  test "drop message_group migrations are gone" do
    assert_empty Dir[Rails.root.join("db/migrate/*drop_message_group*")]
    assert_empty Dir[RecordingStudioSupport::Engine.root.join("db/migrate/*drop_message_group*")]
  end

  private

  def connection
    ActiveRecord::Base.connection
  end
end
