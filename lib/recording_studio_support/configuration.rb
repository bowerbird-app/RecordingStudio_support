# frozen_string_literal: true

module RecordingStudioSupport
  class Configuration
    DEFAULTS = {
      enable_feature_x: false,
      timeout: 5,
      pages_path: "/support",
      public_pages_path: "/help",
      help_title: "Help",
      help_subtitle: "Answers you can share.",
      public_help_title: "Help",
      public_help_subtitle: "Answers you can read.",
      admin_help_title: "Help",
      admin_help_subtitle: "Pages people use when they get stuck."
    }.freeze

    attr_accessor :api_key, *DEFAULTS.keys
    attr_reader :hooks

    def initialize
      @api_key = ENV.fetch("RECORDING_STUDIO_SUPPORT_API_KEY", nil)
      assign_defaults
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      snapshot = { api_key: api_key, hooks_registered: hook_counts }
      DEFAULTS.each_key { |key| snapshot[key] = public_send(key) }
      snapshot
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    private

    def assign_defaults
      DEFAULTS.each { |key, value| public_send("#{key}=", value) }
    end

    def hook_counts
      hooks.instance_variable_get(:@registry).transform_values(&:size)
    end
  end
end
