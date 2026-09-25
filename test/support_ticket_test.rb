# frozen_string_literal: true

require "test_helper"

class SupportTicketTest < Minitest::Test
  def test_status_and_priority_enums_in_model_source
    source = File.read(
      File.expand_path("../app/models/recording_studio_support/support_ticket.rb", __dir__)
    )

    assert_includes source, "open"
    assert_includes source, "waiting_on_customer"
    assert_includes source, "waiting_on_support"
    assert_includes source, "resolved"
    assert_includes source, "low"
    assert_includes source, "normal"
    assert_includes source, "high"
  end

  def test_model_points_at_message_group_and_optional_assignee
    source = File.read(
      File.expand_path("../app/models/recording_studio_support/support_ticket.rb", __dir__)
    )

    assert_includes source, "belongs_to :assignee, polymorphic: true, optional: true"
    assert_includes source, "validates :message_group_id, presence: true, uniqueness: true"
    assert_includes source, "validates :subject, presence: true"
    assert_includes source, "def sync_resolved_at"
  end

  def test_migration_creates_tickets_table
    migration = File.read(
      File.expand_path("../db/migrate/20260925030000_create_recording_studio_support_tickets.rb", __dir__)
    )

    assert_includes migration, "create_table :recording_studio_support_tickets"
    assert_includes migration, "t.uuid :message_group_id, null: false"
    assert_includes migration, 't.string :status, null: false, default: "open"'
    assert_includes migration, 't.string :priority, null: false, default: "normal"'
    assert_includes migration, "t.string :subject, null: false"
    assert_includes migration, "t.datetime :resolved_at"
  end

  def test_tickets_module_exposes_open
    assert_respond_to RecordingStudioSupport::Tickets, :open!
    assert defined?(RecordingStudioSupport::Tickets::Open)
  end
end
