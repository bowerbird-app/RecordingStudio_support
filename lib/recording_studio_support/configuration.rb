# frozen_string_literal: true

module RecordingStudioSupport
  class Configuration
    DEFAULTS = {
      pages_path: "/admin/support",
      public_pages_path: "/help",
      help_title: "Help",
      help_subtitle: "Find an answer.",
      public_help_title: "Hi, how can we help?",
      public_help_subtitle: "Find an answer.",
      admin_help_title: "Support",
      admin_help_subtitle: "Pages people use when they get stuck.",
      public_section_subtitle: nil,
      public_contact_href: "/help/messages",
      public_contact_label: "Contact support",
      # Staff set for the support messages desk. When set to an email string,
      # only that user is staff. When blank, `messages_admin_finder` runs
      # (default: all User rows with admin: true).
      messages_admin_email: nil,
      messages_admin_finder: nil
    }.freeze

    attr_accessor(*DEFAULTS.keys)
    attr_reader :hooks, :layout

    def initialize
      assign_defaults
      @hooks = RecordingStudio::Hooks.new
    end

    def layout=(value)
      @layout = RecordingStudio::Layout.accept(value)
    end

    def to_h
      snapshot = { hooks_registered: hook_counts, layout: layout }
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
