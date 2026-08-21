# frozen_string_literal: true

module RecordingStudioSupport
  class Configuration
    attr_accessor :api_key, :enable_feature_x, :timeout, :pages_path
    attr_reader :hooks

    def initialize
      @api_key = ENV.fetch("RECORDING_STUDIO_SUPPORT_API_KEY", nil)
      @enable_feature_x = false
      @timeout = 5
      @pages_path = "/support"
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        api_key: api_key,
        enable_feature_x: enable_feature_x,
        timeout: timeout,
        pages_path: pages_path,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end
  end
end
