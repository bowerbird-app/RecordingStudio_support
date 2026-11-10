# frozen_string_literal: true

require "test_helper"

class OpenAccessManagementTest < Minitest::Test
  Actor = Struct.new(:id)
  RecordingStub = Struct.new(:recordable_type, :parent_recording_id)

  def setup
    skip "Accessible not loaded" unless defined?(RecordingStudioAccessible)

    @configuration = RecordingStudioAccessible.configuration
    @previous = @configuration.access_management_authorizer
    @calls = []
    @configuration.access_management_authorizer = lambda do |**|
      @calls << :original
      false
    end
    @actor = Actor.new(7)
    @other = Actor.new(8)
    @mount = Struct.new(:id).new("mount-1")
    reset_open_access!
  end

  def teardown
    return unless @configuration

    @configuration.access_management_authorizer = @previous
    reset_open_access!
    Thread.current[RecordingStudioSupport::Messages::OpenAccessManagement::THREAD_KEY] = nil
  end

  def test_with_is_only_open_on_the_current_thread
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @actor, mount: @mount) do
      assert RecordingStudioSupport::Messages::OpenAccessManagement.open?

      other_thread_open = nil
      Thread.new do
        other_thread_open = RecordingStudioSupport::Messages::OpenAccessManagement.open?
      end.join

      refute other_thread_open
    end

    refute RecordingStudioSupport::Messages::OpenAccessManagement.open?
  end

  def test_authorize_does_not_skip_unrelated_recordings_while_open
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @actor, mount: @mount) do
      refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
        recording: :recording,
        actor: @actor
      )
    end

    assert_includes @calls, :original
  end

  def test_authorize_allows_only_the_opener_first_empty_support_group
    group = RecordingStub.new("RecordingStudioMessages::MessageGroup", "mount-1")

    RecordingStudioAccessible.stub(:access_recordings_for, ->(_recording) { [] }) do
      RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @actor, mount: @mount) do
        assert RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: group,
          actor: @actor
        )
        refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: group,
          actor: @other
        )
        refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: RecordingStub.new("Workspace", "mount-1"),
          actor: @actor
        )
        refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: RecordingStub.new("RecordingStudioMessages::MessageGroup", "other-mount"),
          actor: @actor
        )
      end
    end

    assert_includes @calls, :original
  end

  def test_authorize_calls_original_once_the_group_already_has_access
    group = RecordingStub.new("RecordingStudioMessages::MessageGroup", "mount-1")

    RecordingStudioAccessible.stub(:access_recordings_for, ->(_recording) { [:existing] }) do
      RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @actor, mount: @mount) do
        refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: group,
          actor: @actor
        )
      end
    end

    assert_includes @calls, :original
  end

  def test_nested_with_restores_previous_thread_state
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @actor, mount: @mount) do
      RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @actor, mount: @mount) do
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

    refute authorizer.call(recording: recording, actor: @actor)
    assert_includes @calls, :original
  end

  def test_source_does_not_return_true_for_any_open_check
    source = File.read(
      File.expand_path("../lib/recording_studio_support/messages/open_access_management.rb", __dir__)
    )

    refute_includes source, "return true if open?"
  end

  private

  def reset_open_access!
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@authorizer_callable, nil)
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@original, nil)
    RecordingStudioSupport::Messages::OpenAccessManagement.instance_variable_set(:@role_ceiling_wrapped, nil)
  end
end
