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
    reset_open_access!
  end

  def teardown
    return unless @configuration

    @configuration.access_management_authorizer = @previous
    reset_open_access!
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

  def test_install_composes_under_membership_lock_without_recursion
    skip "Messages MembershipLock not loaded" unless defined?(RecordingStudioMessages::MembershipLock)

    RecordingStudioMessages::MembershipLock.install_authorizer_wrap!
    RecordingStudioSupport::Messages::OpenAccessManagement.install!
    RecordingStudioMessages::MembershipLock.install_authorizer_wrap!

    authorizer = @configuration.access_management_authorizer
    lock = RecordingStudioMessages::MembershipLock
    assert authorizer.equal?(lock.instance_variable_get(:@membership_lock_authorizer))
    assert_equal(
      RecordingStudioSupport::Messages::OpenAccessManagement.send(:authorizer_callable),
      lock.instance_variable_get(:@membership_lock_inner)
    )

    recording = Object.new
    def recording.recordable_type
      "Other"
    end

    refute authorizer.call(recording: recording, actor: :actor)
    assert_includes @calls, :original
  end

  private

  def reset_open_access!
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@authorizer_callable, nil)
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@original, nil)
  end
end
