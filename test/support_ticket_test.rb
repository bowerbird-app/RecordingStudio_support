# frozen_string_literal: true

require "test_helper"

class SupportTicketTest < Minitest::Test
  def test_status_and_priority_enums_in_model_source
    source = File.read(
      File.expand_path("../app/models/recording_studio_support/support_ticket.rb", __dir__)
    )

    assert_includes source, "open"
    refute_includes source, "waiting_on_customer"
    refute_includes source, "waiting_on_support"
    assert_includes source, "resolved"
    assert_match(/STATUSES = %w\[\s*open\s*resolved\s*\]/m, source)
    assert_includes source, "low"
    assert_includes source, "normal"
    assert_includes source, "high"
  end

  def test_model_is_a_support_center_recordable
    source = File.read(
      File.expand_path("../app/models/recording_studio_support/support_ticket.rb", __dir__)
    )

    assert_includes source, 'label: "Support ticket"'
    assert_includes source, "root: false"
    assert_includes source, 'allowed_parent_types: ["RecordingStudioSupport::SupportCenter"]'
    assert_includes source, "validates :subject, presence: true"
    assert_includes source, "def sync_resolved_at"
    refute_includes source, "message_group_id"
    refute_includes source, "def message_group_recording"
  end

  def test_ticket_migrations_do_not_use_message_group_id
    create = File.read(
      File.expand_path("../db/migrate/20260925030000_create_recording_studio_support_tickets.rb", __dir__)
    )
    drop = Dir.glob(File.expand_path("../db/migrate/*drop_message_group*", __dir__))

    assert_empty drop
    assert_includes create, "create_table :recording_studio_support_tickets"
    refute_includes create, "message_group_id"
    assert_includes create, 't.string :status, null: false, default: "open"'
    assert_includes create, 't.string :priority, null: false, default: "normal"'
    assert_includes create, "t.string :subject, null: false"
    assert_includes create, "t.datetime :resolved_at"
  end

  def test_tickets_module_exposes_open
    assert_respond_to RecordingStudioSupport::Tickets, :open!
    assert defined?(RecordingStudioSupport::Tickets::Open)
    assert defined?(RecordingStudioSupport::Tickets::ReopenFromCustomerMessage)
    reopen = File.read(
      File.expand_path("../lib/recording_studio_support/tickets/reopen_from_customer_message.rb", __dir__)
    )
    assert_includes reopen, "Tickets.update!"
    assert_includes reopen, "Messages.staff_actor?"
    assert_includes reopen, 'status.to_s == "resolved"'
  end

  def test_current_ticket_join_is_built_when_called
    source = File.read(File.expand_path("../lib/recording_studio_support/tickets.rb", __dir__))

    assert_includes source, "def current_join_sql"
    assert_includes source, "quote_table_name"
    assert_includes source, "recording_studio_trashable_kept_sql"
    refute_includes source, "CURRENT_JOIN"
  end
end
