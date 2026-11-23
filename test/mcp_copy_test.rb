# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  PUBLIC_TOOLS = %w[
    list_support_pages
    show_support_page
    list_support_tickets
    show_support_ticket
    open_support_ticket
    search_support_pages
    list_support_ticket_messages
    reply_to_support_ticket
    mark_support_ticket_read
    count_unread_support_tickets
  ].freeze

  OPERATIONS_TOOLS = %w[
    list_support_centers
    show_support_center
    create_support_center
    list_support_sections
    show_support_section
    create_support_section
    update_support_section
    list_support_pages
    show_support_page
    create_support_page
    update_support_page
    list_support_tickets
    show_support_ticket
    update_support_ticket
    move_support_page
    publish_support_page
    unpublish_support_page
    list_support_ticket_messages
    reply_to_support_ticket
    mark_support_ticket_read
    count_unread_support_tickets
  ].freeze

  def test_register_is_a_noop_without_recording_studio_mcp
    refute Object.const_defined?(:RecordingStudioMcp, false)
    assert_nil RecordingStudioSupport::McpCopy.register!
  end

  def test_tool_names_split_public_and_operations
    assert_equal PUBLIC_TOOLS, RecordingStudioSupport::McpCopy.tool_names(api: :public)
    assert_equal OPERATIONS_TOOLS, RecordingStudioSupport::McpCopy.tool_names(api: :operations)
    refute_includes RecordingStudioSupport::McpCopy.tool_names(api: :public), "create_support_page"
    refute_includes RecordingStudioSupport::McpCopy.tool_names(api: :public), "update_support_ticket"
    refute_includes RecordingStudioSupport::McpCopy.tool_names, "trash_support_page"
    refute_includes RecordingStudioSupport::McpCopy.tool_names, "restore_support_page"
    refute_includes RecordingStudioSupport::McpCopy.tool_names, "purge_support_page"
    refute_includes RecordingStudioSupport::McpCopy.tool_names, "grant_support_center_access"
  end

  def test_mcp_copy_names_the_thing_and_omits_access_wording
    copy = File.read(File.expand_path("../lib/recording_studio_support/mcp_copy.rb", __dir__))
    type = File.read(File.expand_path("../lib/recording_studio_support/mcp_copy/type_descriptions.rb", __dir__))
    operations_path = "../lib/recording_studio_support/mcp_copy/operation_descriptions.rb"
    operations = File.read(File.expand_path(operations_path, __dir__))
    messages = File.read(File.expand_path("../lib/recording_studio_support/api/ticket_messages/copy.rb", __dir__))
    [type, operations, messages].each do |text|
      refute_match(/\bAccess(ible)?\b/, text)
      refute_match(/\b(view|edit|admin) grant\b/i, text)
      refute_includes text, "operations token"
      refute_includes text, "public token"
    end
    assert_includes type, "A SupportTicket is a signed-in help request"
    assert_includes messages, "reopens it"
    tools = File.read(File.expand_path("../lib/recording_studio_support/mcp_copy/registration.rb", __dir__))
    assert_includes copy, "register_tool"
    assert_includes tools, "register_type"
  end

  def test_ticket_message_handlers_wrap_messages_services
    list = File.read(File.expand_path("../lib/recording_studio_support/api/ticket_messages/list.rb", __dir__))
    reply = File.read(File.expand_path("../lib/recording_studio_support/api/ticket_messages/reply.rb", __dir__))
    mark_read = File.read(File.expand_path("../lib/recording_studio_support/api/ticket_messages/mark_read.rb", __dir__))
    unread = File.read(File.expand_path("../lib/recording_studio_support/api/ticket_messages/unread_count.rb", __dir__))
    registration = File.read(File.expand_path("../lib/recording_studio_support/api/ticket_messages.rb", __dir__))

    assert_includes list, "RecordingStudioMessages.message_recordings"
    assert_includes reply, "RecordingStudioMessages.send_message"
    assert_includes mark_read, "RecordingStudioMessages.mark_read"
    assert_includes unread, "RecordingStudioMessages.viewable_group_recordings"
    refute_includes registration, "Messages.place"
    refute_includes registration, "preset: :support"
    refute_includes reply, "Tickets.update!"
  end
end
