# frozen_string_literal: true

require "test_helper"

class OpenAccessManagementTest < Minitest::Test
  RecordingStub = Struct.new(:recordable_type, :parent_recording, :parent_recording_id, :id, keyword_init: true)

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
    @opener = Object.new
    @stranger = Object.new
    @mount = RecordingStub.new(id: 7, recordable_type: "RecordingStudioMessages::MessageMount")
    @group = RecordingStub.new(
      id: 11,
      recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE,
      parent_recording: @mount,
      parent_recording_id: @mount.id
    )
    @other = RecordingStub.new(
      id: 99,
      recordable_type: "Workspace",
      parent_recording: nil,
      parent_recording_id: nil
    )
  end

  def teardown
    return unless @configuration

    @configuration.access_management_authorizer = @previous
    reset_open_access!
    Thread.current[RecordingStudioSupport::Messages::OpenAccessManagement::THREAD_KEY] = nil
  end

  def test_with_opens_only_on_the_current_thread
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @opener, mount: @mount) do
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
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @opener, mount: @mount) do
      refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
        recording: @other,
        actor: @opener
      )
      refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
        recording: @group,
        actor: @stranger
      )
    end

    assert_includes @calls, :original
  end

  def test_authorize_allows_first_owner_grant_on_empty_support_group
    RecordingStudioAccessible.stub(:access_recordings_for, []) do
      RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @opener, mount: @mount) do
        assert RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: @group,
          actor: @opener
        )
      end
    end

    refute_includes @calls, :original
  end

  def test_authorize_falls_through_once_the_group_already_has_access
    existing = [Object.new]
    RecordingStudioAccessible.stub(:access_recordings_for, existing) do
      RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @opener, mount: @mount) do
        refute RecordingStudioSupport::Messages::OpenAccessManagement.authorize(
          recording: @group,
          actor: @opener
        )
      end
    end

    assert_includes @calls, :original
  end

  def test_nested_with_restores_previous_thread_state
    RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @opener, mount: @mount) do
      RecordingStudioSupport::Messages::OpenAccessManagement.with(actor: @opener, mount: @mount) do
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
  end
end
