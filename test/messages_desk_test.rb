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

  def test_find_or_create_returns_nil_without_actor
    assert_nil RecordingStudioSupport::Messages.find_or_create_user_group(actor: nil)
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

  def test_create_user_group_uses_thread_local_open_access_gate
    source = File.read(File.expand_path("../lib/recording_studio_support/messages.rb", __dir__))

    assert_includes source, "OpenAccessManagement.with"
    refute_includes source, "configuration.access_management_authorizer = ->(**) { true }"
  end
end
