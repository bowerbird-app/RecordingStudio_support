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
        validate :icon_is_known_flatpack_heroicon

        before_validation :normalize_icon
      end

      def self.known_heroicon?(name)
        return false if name.blank?

        canonical = FlatPack::Shared::IconComponent::NAME_MAP.fetch(name.to_s, name.to_s)
        variant = FlatPack.configuration.default_icon_variant
        FlatPack::Heroicons.fetch(variant, canonical).present?
      end

      private

      def normalize_icon
        self.icon = icon.to_s.strip.downcase.tr("_", "-").presence
      end

      def icon_is_known_flatpack_heroicon
        return if icon.blank?
        return unless icon.match?(ICON_FORMAT)
        return if HasHeroicon.known_heroicon?(icon)

        errors.add(:icon, "\"#{icon}\" is not a known FlatPack icon")
      end
    end
  end
end
