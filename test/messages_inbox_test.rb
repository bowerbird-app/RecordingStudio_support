# frozen_string_literal: true

require "test_helper"

class MessagesInboxTest < Minitest::Test
  def test_support_mount_key
    assert_equal :support, RecordingStudioSupport::Messages::SUPPORT_MOUNT_KEY
  end

  def test_one_to_one_user_group_helpers_are_gone
    refute RecordingStudioSupport::Messages.respond_to?(:find_or_create_user_group)
    refute RecordingStudioSupport::Messages.respond_to?(:user_group_on_mount)
    refute RecordingStudioSupport::Messages.respond_to?(:create_user_group!)
  end

  def test_support_config_is_accessible_not_user_admin
    defaults = RecordingStudioSupport::Configuration::DEFAULTS

    assert_equal "AdminRoot", defaults[:parent_root_type]
    refute_includes defaults.keys, :messages_admin_email
    refute_includes defaults.keys, :messages_admin_finder
    source = File.read(File.expand_path("../lib/recording_studio_support/messages/support_team.rb", __dir__))
    refute_includes source, "User.where(admin: true)"
    refute_includes source, "messages_admin_email"
    assert_includes source, "authorized?"
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
    source = File.read(File.expand_path("../lib/recording_studio_support/messages/support_team.rb", __dir__))

    assert_includes source, "def support_team_has_edit?"
    assert_includes source, "%w[edit admin]"
    assert_includes source, "next if support_team_has_edit?"
    assert_includes source, "access_recordings_for_actor"
  end

  def test_sync_support_team_grants_uses_membership_change_bypass
    source = File.read(File.expand_path("../lib/recording_studio_support/messages/support_team.rb", __dir__))

    assert_includes source, "RecordingStudioMessages.allow_membership_change"
    assert_includes source, "def sync_support_team_grants!"
  end

  def test_access_button_targets_the_top_frame
    source = File.read(
      File.expand_path("../lib/recording_studio_support/messages/inbox_access_navigation.rb", __dir__)
    )

    assert_includes source, "turbo_frame: \"_top\""
    assert_includes source, "def recording_studio_accessible_button"
  end

  def test_panel_header_installs_inbox_helper_hooks
    install = File.read(File.expand_path("../lib/recording_studio_support/messages/panel_header.rb", __dir__))
    helper = File.read(File.expand_path("../app/helpers/recording_studio_support/messages_inbox_helper.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_support/engine.rb", __dir__))

    assert_includes install, "RecordingStudioMessages::PanelHelper"
    assert_includes install, "MessagesInboxHelper"
    assert_includes helper, "def messages_unread_filter_index_path"
    assert_includes helper, "def messages_panel_right_header"
    assert_includes helper, "def messages_panel_right_header_mobile"
    assert_includes helper, "def support_ticket_for_header"
    assert_includes helper, "def support_ticket_status_action"
    controls = File.read(
      File.expand_path("../app/views/recording_studio_support/support_inbox/_ticket_controls.html.erb", __dir__)
    )
    assert_includes controls, "FlatPack::Button::Dropdown::Component"
    assert_includes controls, "style: :default"
    refute_includes controls, "FlatPack::Select::Component"
    refute_includes controls, "w-56"
    refute_includes controls, "w-24"
    assert_includes helper, "Messages.support_team_actor?"
    assert_includes helper, "SUPPORT_MOUNT_KEY"
    refute_includes helper, "support_ticket_thread_bar"
    refute_includes engine, "PanelOverride"
    assert_includes engine, "PanelHeader.install!"
    runtime = File.read(File.expand_path("../lib/recording_studio_support/engine/runtime_prepares.rb", __dir__))
    reopen = File.read(File.expand_path("../lib/recording_studio_support/messages/send_message_reopen.rb", __dir__))
    assert_includes runtime, "SendMessageReopen.install!"
    assert_includes reopen, "Tickets::ReopenFromCustomerMessage.call"
    assert_includes reopen, "singleton_class.prepend"
    refute File.exist?(File.expand_path("../lib/recording_studio_support/messages/panel_override.rb", __dir__))
    refute File.exist?(
      File.expand_path(
        "../app/views/overrides/recording_studio_messages/message_groups/_panel.html.erb",
        __dir__
      )
    )
  end

  def test_open_ticket_uses_narrow_first_open_access_gate
    open_source = File.read(File.expand_path("../lib/recording_studio_support/tickets/open.rb", __dir__))
    gate_source = File.read(
      File.expand_path("../lib/recording_studio_support/messages/open_access_management.rb", __dir__)
    )

    assert_includes open_source, "OpenAccessManagement.with(actor: @actor, mount: mount)"
    refute_includes open_source, "configuration.access_management_authorizer = ->(**) { true }"
    refute_includes gate_source, "return true if open?"
    assert_includes gate_source, "first_open_membership_grant?"
    assert_includes gate_source, "wrap_role_ceiling!"
    assert_includes gate_source, "RoleCeilingFirstOpen"
    assert_includes open_source, "tags: { Tickets::TAG_KEY => ticket_recording }"
  end
end
