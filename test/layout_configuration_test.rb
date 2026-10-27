# frozen_string_literal: true

require "test_helper"

class LayoutConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioSupport::Configuration.new
    @core = RecordingStudio.configuration
    @previous_core_layout = @core.layout
  end

  def teardown
    @core.layout = @previous_core_layout
  end

  def test_layout_defaults_to_nil
    assert_nil @configuration.layout
  end

  def test_nil_falls_through_to_core_layout_then_the_default
    @core.layout = "admin"
    assert_equal "admin", resolve(@configuration.layout)

    @core.layout = nil
    assert_equal "recording_studio/default_layout", resolve(@configuration.layout)
  end

  def test_string_layout_is_used_and_does_not_fall_through
    @core.layout = "admin"
    @configuration.layout = "help"

    assert_equal "help", resolve(@configuration.layout)
  end

  def test_false_layout_does_not_fall_through
    @core.layout = "admin"
    @configuration.layout = false

    assert_equal false, resolve(@configuration.layout)
  end

  def test_keyword_callable_layout_receives_the_controller
    controller = Object.new
    seen = nil
    @configuration.layout = lambda do |controller:|
      seen = controller
      "help"
    end

    assert_equal "help", resolve(@configuration.layout, controller: controller)
    assert_same controller, seen
  end

  def test_invalid_layout_raises_argument_error
    assert_raises(ArgumentError) { @configuration.layout = :application }
    assert_raises(ArgumentError) { @configuration.layout = "" }
    assert_raises(ArgumentError) { @configuration.layout = ->(_controller) { "help" } }
    assert_raises(ArgumentError) { @configuration.layout = Object.new }
  end

  def test_controllers_do_not_hardcode_a_recording_studio_layout
    root = File.expand_path("..", __dir__)
    dummy = File.expand_path("dummy", __dir__)

    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(root)
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(dummy)
  end

  private

  # Same lookup as RecordingStudio::ControllerLayout#recording_studio_resolved_layout.
  def resolve(setting, controller: Object.new)
    resolved = RecordingStudio::Layout.resolve(setting, controller: controller)
    return resolved unless resolved.nil?

    @core.resolved_layout(controller: controller)
  end
end
