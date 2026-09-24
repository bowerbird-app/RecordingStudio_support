# frozen_string_literal: true

module RecordingStudioSupport
  module Messages
    # The Messages desk panel is a Turbo frame. Accessible's "+ Access" button
    # lives inside it, so a normal click asks that frame for the access page
    # and Turbo shows "Content missing". Break the button out to the full page.
    module DeskAccessNavigation
      def self.install!
        helper = RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
        return unless helper
        return if helper.ancestors.include?(self)

        helper.prepend(self)
      end

      def recording_studio_accessible_button(recording, button_size:, button_style:, text: nil, **options)
        data = options.fetch(:data, {}).to_h.symbolize_keys
        options[:data] = data.merge(turbo_frame: "_top")
        super
      end
    end
  end
end
