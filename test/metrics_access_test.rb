# frozen_string_literal: true

require "test_helper"

class MetricsAccessTest < Minitest::Test
  def test_metrics_view_prefers_site_admin_resolver
    site_recording = Object.new
    access_recording = Object.new
    actor = Object.new
    seen_context = nil
    access_called = false
    site = lambda do |resolver_context|
      seen_context = resolver_context
      site_recording
    end
    access = lambda do |_resolver_context|
      access_called = true
      access_recording
    end

    decision = nil
    result = with_admin_resolvers(site: site, access: access) do
      stub_authorized(lambda { |actor:, recording:, role:|
        decision = { actor: actor, recording: recording, role: role }
        true
      }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal true, result
    assert_nil seen_context.controller
    assert_same site_recording, decision[:recording]
    assert_same actor, decision[:actor]
    assert_equal :view, decision[:role]
    refute access_called
  end

  def test_metrics_view_falls_back_to_access_resolver
    access_recording = Object.new
    actor = Object.new
    seen_context = nil
    access = lambda do |resolver_context|
      seen_context = resolver_context
      access_recording
    end

    decision = nil
    result = with_admin_resolvers(site: nil, access: access) do
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
    assert_equal :view, decision[:role]
  end

  def test_metrics_view_denies_when_resolver_raises
    actor = Object.new
    raising = ->(_resolver_context) { raise NoMethodError, "undefined method `controller' for nil" }
    access_called = false

    result = with_admin_resolvers(site: raising, access: lambda { |_resolver_context|
      access_called = true
      Object.new
    }) do
      stub_authorized(->(**) { flunk "Accessible should not run when the resolver raises" }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal false, result
    refute access_called

    fallback = with_admin_resolvers(site: nil, access: raising) do
      stub_authorized(->(**) { flunk "Accessible should not run when the resolver raises" }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal false, fallback
  end

  def test_metrics_view_denies_when_resolver_returns_nil
    actor = Object.new
    access_called = false

    result = with_admin_resolvers(site: ->(_resolver_context) {}, access: lambda { |_resolver_context|
      access_called = true
      Object.new
    }) do
      stub_authorized(->(**) { flunk "Accessible should not run without an admin root" }) do
        RecordingStudioSupport::Api::Access.can_view_metrics?(context_for(actor))
      end
    end

    assert_equal false, result
    refute access_called
  end

  def test_staff_create_move_and_write_keep_access_resolver
    site_recording = Object.new
    access_recording = Object.new
    actor = Object.new
    site_called = false
    site = lambda do |_resolver_context|
      site_called = true
      site_recording
    end
    access = ->(_resolver_context) { access_recording }
    seen = []

    with_admin_resolvers(site: site, access: access) do
      stub_authorized(lambda { |recording:, role:, **|
        seen << [recording, role]
        true
      }) do
        assert RecordingStudioSupport::Api::Access.can_view_as_staff?(context_for(actor))
        assert RecordingStudioSupport::Api::Access.can_edit?(context_for(actor))
        assert RecordingStudioSupport::Api::Access.admin_root_edit?(actor)
      end
    end

    refute site_called
    assert_equal [
      [access_recording, :view],
      [access_recording, :edit],
      [access_recording, :edit]
    ], seen

    with_admin_resolvers(site: ->(_) { site_recording }, access: ->(_) { raise NoMethodError, "nil controller" }) do
      error = assert_raises(NoMethodError) do
        RecordingStudioSupport::Api::Access.can_edit?(context_for(actor))
      end
      assert_match "nil controller", error.message

      assert_raises(NoMethodError) do
        RecordingStudioSupport::Api::Access.can_view_as_staff?(context_for(actor))
      end
    end
  end

  private

  def context_for(actor)
    Struct.new(:actor).new(actor)
  end

  def with_admin_resolvers(site:, access:, &)
    config = RecordingStudioAdmin::Configuration.new
    config.site_admin_recording_resolver = site
    config.access_recording_resolver = access
    RecordingStudioAdmin.stub(:configuration, config, &)
  end

  def stub_authorized(decision, &)
    RecordingStudioAccessible.stub(:authorized?, decision, &)
  end
end
