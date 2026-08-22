# frozen_string_literal: true

module RecordingStudioSupport
  class Configuration
    attr_accessor :api_key, :enable_feature_x, :timeout, :pages_path, :public_pages_path,
                  :help_title, :help_subtitle, :public_help_title, :public_help_subtitle,
                  :admin_help_title, :admin_help_subtitle
    attr_reader :hooks

    def initialize
      @api_key = ENV.fetch("RECORDING_STUDIO_SUPPORT_API_KEY", nil)
      @enable_feature_x = false
      @timeout = 5
      @pages_path = "/support"
      @public_pages_path = "/help"
      assign_help_copy_defaults
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h # rubocop:disable Metrics/MethodLength
      {
        api_key: api_key,
        enable_feature_x: enable_feature_x,
        timeout: timeout,
        pages_path: pages_path,
        public_pages_path: public_pages_path,
        **help_copy_values,
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

    private

    def assign_help_copy_defaults
      @help_title = "Help"
      @help_subtitle = "Answers you can share."
      @public_help_title = "Help"
      @public_help_subtitle = "Answers you can read."
      @admin_help_title = "Help"
      @admin_help_subtitle = "Pages people use when they get stuck."
    end

    def help_copy_values
      {
        help_title: help_title,
        help_subtitle: help_subtitle,
        public_help_title: public_help_title,
        public_help_subtitle: public_help_subtitle,
        admin_help_title: admin_help_title,
        admin_help_subtitle: admin_help_subtitle
      }
    end
  end
end
