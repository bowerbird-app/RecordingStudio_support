# frozen_string_literal: true

require "test_helper"

class MessagesDeskTest < Minitest::Test
  def setup
    @previous_email = RecordingStudioSupport.configuration.messages_admin_email
    @previous_finder = RecordingStudioSupport.configuration.messages_admin_finder
    RecordingStudioSupport.configuration.messages_admin_email = nil
    RecordingStudioSupport.configuration.messages_admin_finder = nil
  end

  def teardown
    RecordingStudioSupport.configuration.messages_admin_email = @previous_email
    RecordingStudioSupport.configuration.messages_admin_finder = @previous_finder
  end

  def test_support_mount_key
    assert_equal :support, RecordingStudioSupport::Messages::SUPPORT_MOUNT_KEY
  end

  def test_one_to_one_user_group_helpers_are_gone
    refute RecordingStudioSupport::Messages.respond_to?(:find_or_create_user_group)
    refute RecordingStudioSupport::Messages.respond_to?(:user_group_on_mount)
    refute RecordingStudioSupport::Messages.respond_to?(:create_user_group!)
  end

  def test_messages_admin_email_is_the_staff_config_key
    assert_includes RecordingStudioSupport::Configuration::DEFAULTS.keys, :messages_admin_email
    assert_nil RecordingStudioSupport::Configuration::DEFAULTS[:messages_admin_email]
  end

  def test_public_contact_href_defaults_to_help_messages
    configuration = RecordingStudioSupport::Configuration.new

    assert_equal "/help/messages", configuration.public_contact_href
  end

  def test_message_received_registers_email_channel
    RecordingStudioMessages.register_integration!
    RecordingStudioSupport::Engine.register_message_received_with_email!
    type = RecordingStudioNotifications.notification_types.fetch(:message_received)

    assert_includes type.default_channels, :in_app
    assert_includes type.default_channels, :email
    assert_includes type.available_channels, :email
  end

  def test_already_granted_requires_edit_not_any_access
    source = File.read(File.expand_path("../lib/recording_studio_support/messages/staff.rb", __dir__))

    assert_includes source, "def staff_has_edit?"
    assert_includes source, "%w[edit admin]"
    assert_includes source, "next if staff_has_edit?"
    assert_includes source, "access_recordings_for_actor"
  end

  def test_sync_staff_grants_uses_membership_change_bypass
    source = File.read(File.expand_path("../lib/recording_studio_support/messages/staff.rb", __dir__))

    assert_includes source, "RecordingStudioMessages.allow_membership_change"
    assert_includes source, "def sync_staff_grants!"
  end

  def test_desk_access_button_targets_the_top_frame
    source = File.read(
      File.expand_path("../lib/recording_studio_support/messages/desk_access_navigation.rb", __dir__)
    )

    assert_includes source, "turbo_frame: \"_top\""
    assert_includes source, "def recording_studio_accessible_button"
  end

  def test_open_ticket_uses_thread_local_open_access_gate
    source = File.read(File.expand_path("../lib/recording_studio_support/tickets/open.rb", __dir__))

    assert_includes source, "OpenAccessManagement.with"
    refute_includes source, "configuration.access_management_authorizer = ->(**) { true }"
  end
end
