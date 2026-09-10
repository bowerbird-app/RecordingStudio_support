# frozen_string_literal: true

module RecordingStudioSupport
  class SupportSection < ApplicationRecord
    self.table_name = "recording_studio_support_sections"

    RESERVED_SLUGS = %w[sections new edit].freeze
    SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    ICON_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    recording_studio_recordable label: "Help section",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    include RecordingStudio::Capabilities::Trashable.to
    include RecordingStudio::Capabilities::Orderable.to(
      allows: ["RecordingStudioSupport::SupportPage"]
    )

    validates :title, presence: true
    validates :slug, presence: true
    validates :slug, format: { with: SLUG_FORMAT, message: "must use URL-safe lowercase slug segments" }
    validates :icon,
              format: { with: ICON_FORMAT, message: "must be a Heroicons name like credit-card" },
              allow_blank: true
    validate :slug_is_not_reserved

    before_validation :assign_slug_from_title
    before_validation :normalize_icon

    def self.slug_for(title, excluding_id: nil)
      base = title.to_s.parameterize.presence || "section"
      base = "section" if RESERVED_SLUGS.include?(base)
      unique_slug(base, excluding_id: excluding_id)
    end

    def self.unique_slug(base, excluding_id: nil)
      candidate = base
      suffix = 2

      while slug_taken?(candidate, excluding_id: excluding_id)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      candidate
    end

    def self.slug_taken?(slug, excluding_id: nil)
      relation = joins(current_kept_join_sql).where(slug: slug)
      relation = relation.where.not(recording_studio_support_sections: { id: excluding_id }) if excluding_id.present?
      relation.exists?
    end

    def self.current_kept_join_sql
      table = RecordingStudio::Recording.table_name
      type = ActiveRecord::Base.connection.quote("RecordingStudioSupport::SupportSection")
      "INNER JOIN #{table} ON #{table}.recordable_id = recording_studio_support_sections.id " \
        "AND #{table}.recordable_type = #{type} " \
        "AND #{table}.trashed_at IS NULL"
    end

    private

    def assign_slug_from_title
      return if title.blank?
      return if slug.present?

      self.slug = self.class.slug_for(title, excluding_id: id)
    end

    def normalize_icon
      self.icon = icon.to_s.strip.downcase.tr("_", "-").presence
    end

    def slug_is_not_reserved
      return if slug.blank?
      return unless RESERVED_SLUGS.include?(slug)

      errors.add(:slug, "is reserved")
    end
  end
end
