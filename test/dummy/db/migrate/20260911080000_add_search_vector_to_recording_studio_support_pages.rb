# frozen_string_literal: true

class AddSearchVectorToRecordingStudioSupportPages < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    unless column_exists?(:recording_studio_support_pages, :search_vector)
      add_column :recording_studio_support_pages, :search_vector, :tsvector,
                 as: "setweight(to_tsvector('english', coalesce(title::text, '')), 'A') || " \
                     "setweight(to_tsvector('english', coalesce(body::text, '')), 'D')",
                 stored: true
    end

    unless index_name_exists?(:recording_studio_support_pages, "index_recording_studio_support_pages_on_search_vector")
      add_index :recording_studio_support_pages, :search_vector,
                using: :gin,
                name: "index_recording_studio_support_pages_on_search_vector"
    end

    unless index_name_exists?(:recording_studio_support_pages, "index_recording_studio_support_pages_on_title_trgm")
      add_index :recording_studio_support_pages, :title,
                opclass: :gin_trgm_ops,
                using: :gin,
                name: "index_recording_studio_support_pages_on_title_trgm"
    end

    unless index_name_exists?(:recording_studio_support_pages, "index_recording_studio_support_pages_on_body_trgm")
      add_index :recording_studio_support_pages, :body,
                opclass: :gin_trgm_ops,
                using: :gin,
                name: "index_recording_studio_support_pages_on_body_trgm"
    end
  end

  def down
    if index_name_exists?(:recording_studio_support_pages, "index_recording_studio_support_pages_on_body_trgm")
      remove_index :recording_studio_support_pages, name: "index_recording_studio_support_pages_on_body_trgm"
    end
    if index_name_exists?(:recording_studio_support_pages, "index_recording_studio_support_pages_on_title_trgm")
      remove_index :recording_studio_support_pages, name: "index_recording_studio_support_pages_on_title_trgm"
    end
    if index_name_exists?(:recording_studio_support_pages, "index_recording_studio_support_pages_on_search_vector")
      remove_index :recording_studio_support_pages, name: "index_recording_studio_support_pages_on_search_vector"
    end
    if column_exists?(:recording_studio_support_pages, :search_vector)
      remove_column :recording_studio_support_pages, :search_vector
    end
  end
end
