# frozen_string_literal: true

module RecordingStudioSupport
  module Concerns
    module HasHeroicon
      extend ActiveSupport::Concern

      ICON_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

      included do
        validates :icon,
                  format: { with: ICON_FORMAT, message: "must be a Heroicons name like credit-card" },
                  allow_blank: true

        before_validation :normalize_icon
      end

      private

      def normalize_icon
        self.icon = icon.to_s.strip.downcase.tr("_", "-").presence
      end
    end
  end
end
