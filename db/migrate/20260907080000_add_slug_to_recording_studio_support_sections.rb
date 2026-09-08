# frozen_string_literal: true

class AddSlugToRecordingStudioSupportSections < ActiveRecord::Migration[8.1]
  SLUG_INDEX = "index_rs_support_sections_on_slug"

  def up
    add_column :recording_studio_support_sections, :slug, :string
    backfill_slugs
    change_column_null :recording_studio_support_sections, :slug, false
    add_index :recording_studio_support_sections, :slug, name: SLUG_INDEX
  end

  def down
    remove_index :recording_studio_support_sections, name: SLUG_INDEX
    remove_column :recording_studio_support_sections, :slug
  end

  private

  def backfill_slugs
    say_with_time "backfill support section slugs" do
      connection.select_all("SELECT id, title FROM recording_studio_support_sections").each do |row|
        slug = unique_slug_for(row["title"], excluding_id: row["id"])
        execute(
          "UPDATE recording_studio_support_sections SET slug = #{connection.quote(slug)} " \
          "WHERE id = #{connection.quote(row['id'])}"
        )
      end
    end
  end

  def unique_slug_for(title, excluding_id:)
    base = title.to_s.parameterize.presence || "section"
    base = "section" if %w[sections new edit].include?(base)
    candidate = base
    suffix = 2

    while slug_taken?(candidate, excluding_id: excluding_id)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end

  def slug_taken?(slug, excluding_id:)
    connection.select_value(
      "SELECT 1 FROM recording_studio_support_sections " \
      "WHERE slug = #{connection.quote(slug)} AND id <> #{connection.quote(excluding_id)} LIMIT 1"
    ).present?
  end
end
