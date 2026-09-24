# frozen_string_literal: true

require "test_helper"

class OpenAccessManagementTest < Minitest::Test
  def setup
    skip "Accessible not loaded" unless defined?(RecordingStudioAccessible)

    @configuration = RecordingStudioAccessible.configuration
    @previous = @configuration.access_management_authorizer
    @calls = []
    @configuration.access_management_authorizer = lambda do |**|
      @calls << :original
      false
    end
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@installed, false)
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@original, nil)
  end

  def teardown
    return unless @configuration

    @configuration.access_management_authorizer = @previous
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@installed, false)
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@original, nil)
    Thread.current[RecordingStudioSupport::Messages::OpenAccessManagement::THREAD_KEY] = nil
  end

  def test_with_opens_only_on_the_current_thread
    RecordingStudioSupport::Messages::OpenAccessManagement.with do
      assert RecordingStudioSupport::Messages::OpenAccessManagement.open?
      assert RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
        recording: :recording,
        actor: :actor
      )

      other_thread_open = nil
      other_thread_authorized = nil
      Thread.new do
        other_thread_open = RecordingStudioSupport::Messages::OpenAccessManagement.open?
        other_thread_authorized = RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: :recording,
          actor: :actor
        )
      end.join

      refute other_thread_open
      refute other_thread_authorized
    end

    refute RecordingStudioSupport::Messages::OpenAccessManagement.open?
    assert_includes @calls, :original
  end

  def test_nested_with_restores_previous_thread_state
    RecordingStudioSupport::Messages::OpenAccessManagement.with do
      RecordingStudioSupport::Messages::OpenAccessManagement.with do
        assert RecordingStudioSupport::Messages::OpenAccessManagement.open?
      end
      assert RecordingStudioSupport::Messages::OpenAccessManagement.open?
    end

    refute RecordingStudioSupport::Messages::OpenAccessManagement.open?
  end
end
