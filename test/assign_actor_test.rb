# frozen_string_literal: true

require "test_helper"

class AssignActorTest < Minitest::Test
  FakeCurrent = Class.new do
    class << self
      attr_accessor :actor
    end
  end

  def setup
    @had_current = Object.const_defined?(:Current)
    @previous_current = Current if @had_current
    Object.send(:remove_const, :Current) if @had_current
    Object.const_set(:Current, FakeCurrent)
    FakeCurrent.actor = :original
  end

  def teardown
    Object.send(:remove_const, :Current) if Object.const_defined?(:Current)
    Object.const_set(:Current, @previous_current) if @had_current
    FakeCurrent.actor = nil
  end

  def test_nil_actor_yields_without_changing_current
    result = RecordingStudioSupport::AssignActor.assign_actor(nil) do
      assert_equal :original, Current.actor
      :yielded
    end

    assert_equal :yielded, result
    assert_equal :original, Current.actor
  end

  def test_sets_current_actor_for_the_block_and_restores_after
    result = RecordingStudioSupport::AssignActor.assign_actor(:staff) do
      assert_equal :staff, Current.actor
      :done
    end

    assert_equal :done, result
    assert_equal :original, Current.actor
  end

  def test_restores_current_actor_when_the_block_raises
    assert_raises(RuntimeError) do
      RecordingStudioSupport::AssignActor.assign_actor(:staff) do
        raise "boom"
      end
    end

    assert_equal :original, Current.actor
  end

  def test_pages_and_sections_share_the_helper
    shared = RecordingStudioSupport::AssignActor.instance_method(:assign_actor).source_location
    assert_equal shared, RecordingStudioSupport::Pages.method(:assign_actor).source_location
    assert_equal shared, RecordingStudioSupport::Sections.method(:assign_actor).source_location
  end
end
