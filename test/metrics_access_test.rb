# frozen_string_literal: true

require "test_helper"

class MetricsAccessTest < Minitest::Test
  def test_metrics_view_uses_access_recording_resolver
    access_recording = Object.new
    actor = Object.new
    seen_context = nil
    access = lambda do |resolver_context|
      seen_context = resolver_context
      access_recording
    end

    decision = nil
    result = with_admin_resolver(access) do
      stub_authorized(lambda { |actor:, recording:, role:|
        decision = { actor: actor, recording: recording, role: role }
        true
      }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal true, result
    assert_nil seen_context.controller
    assert_same access_recording, decision[:recording]
    assert_same actor, decision[:actor]
    assert_equal :view, decision[:role]
  end

  def test_metrics_view_denies_when_resolver_raises
    actor = Object.new
    raising = ->(_resolver_context) { raise NoMethodError, "undefined method `controller' for nil" }

    result = with_admin_resolver(raising) do
      stub_authorized(->(**) { flunk "Accessible should not run when the resolver raises" }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal false, result
  end

  def test_metrics_view_denies_when_resolver_returns_nil
    actor = Object.new

    result = with_admin_resolver(->(_resolver_context) {}) do
      stub_authorized(->(**) { flunk "Accessible should not run without an admin root" }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal false, result
  end

  def test_support_create_move_and_write_use_access_resolver
    access_recording = Object.new
    actor = Object.new
    access = ->(_resolver_context) { access_recording }
    seen = []

    with_admin_resolver(access) do
      stub_authorized(lambda { |recording:, role:, **|
        seen << [recording, role]
        true
      }) do
        assert RecordingStudioSupport::Api::Access.can_view_as_support_team?(context_for(actor))
        assert RecordingStudioSupport::Api::Access.can_edit?(context_for(actor))
        assert RecordingStudioSupport::Api::Access.admin_root_edit?(actor)
      end
    end

    assert_equal [
      [access_recording, :view],
      [access_recording, :edit],
      [access_recording, :edit]
    ], seen

    with_admin_resolver(->(_) { raise NoMethodError, "nil controller" }) do
      error = assert_raises(NoMethodError) do
        RecordingStudioSupport::Api::Access.can_edit?(context_for(actor))
      end
      assert_match "nil controller", error.message

      assert_raises(NoMethodError) do
        RecordingStudioSupport::Api::Access.can_view_as_support_team?(context_for(actor))
      end
    end
  end

  private

  def context_for(actor)
    Struct.new(:actor).new(actor)
  end

  def with_admin_resolver(access, &)
    config = RecordingStudioAdmin::Configuration.new
    config.access_recording_resolver = access
    RecordingStudioAdmin.stub(:configuration, config, &)
  end

  def stub_authorized(decision, &)
    RecordingStudioAccessible.stub(:authorized?, decision, &)
  end
end
