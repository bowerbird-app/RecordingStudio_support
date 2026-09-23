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
end
