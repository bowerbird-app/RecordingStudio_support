# frozen_string_literal: true

require "test_helper"
require "active_support/current_attributes"
require_relative "dummy/app/models/current"

class AssignActorTest < Minitest::Test
  def setup
    @previous_actor = Current.actor
    Current.actor = :original
  end

  def teardown
    Current.actor = @previous_actor
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

  def test_pages_and_sections_keep_public_assign_actor
    assert_includes RecordingStudioSupport::Pages.public_methods, :assign_actor
    assert_includes RecordingStudioSupport::Sections.public_methods, :assign_actor
  end

  def test_pages_and_sections_delegate_to_the_shared_helper
    RecordingStudioSupport::Pages.assign_actor(:staff) do
      assert_equal :staff, Current.actor
    end
    assert_equal :original, Current.actor

    RecordingStudioSupport::Sections.assign_actor(:staff) do
      assert_equal :staff, Current.actor
    end
    assert_equal :original, Current.actor
  end
end
