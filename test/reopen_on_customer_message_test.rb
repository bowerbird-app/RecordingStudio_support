# frozen_string_literal: true

require "test_helper"

class ReopenOnCustomerMessageTest < Minitest::Test
  Handler = RecordingStudioSupport::Messages::ReopenOnCustomerMessage

  def test_hook_is_registered_only_once
    assert_equal 1, after_record_handlers.count(Handler)
    before = after_record_count

    load "recording_studio_support/messages/reopen_on_customer_message.rb"
    Handler.register!

    runtime = File.read(
      File.expand_path("../lib/recording_studio_support/engine/runtime_prepares.rb", __dir__)
    )
    refute_includes runtime, "after_record"
    refute_includes runtime, "ReopenOnCustomerMessage"
    assert_equal before, after_record_count
    assert_equal 1, after_record_handlers.count(Handler)
  end

  private

  def after_record_count
    RecordingStudio.configuration.hooks.registered_counts[:after_record]
  end

  def after_record_handlers
    registry = RecordingStudio.configuration.hooks.instance_variable_get(:@registry)
    Array(registry[:after_record]).map { |entry| entry[:handler] }
  end
end
