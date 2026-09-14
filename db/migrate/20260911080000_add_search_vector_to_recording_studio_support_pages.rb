# frozen_string_literal: true

class AddSearchVectorToRecordingStudioSupportPages < ActiveRecord::Migration[8.1]
  SEARCH_VECTOR_SQL =
    "setweight(to_tsvector('english', coalesce(title::text, '')), 'A') || " \
    "setweight(to_tsvector('english', coalesce(body::text, '')), 'D')"

  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    add_search_vector_column
    add_search_indexes
  end

  def down
    remove_search_indexes
    remove_search_vector_column
  end

  private

  def add_search_vector_column
    return if column_exists?(:recording_studio_support_pages, :search_vector)

    add_column :recording_studio_support_pages, :search_vector, :tsvector,
               as: SEARCH_VECTOR_SQL,
               stored: true
  end

  def add_search_indexes
    add_gin_index_unless_exists(:search_vector, "index_recording_studio_support_pages_on_search_vector")
    add_trgm_index_unless_exists(:title, "index_recording_studio_support_pages_on_title_trgm")
    add_trgm_index_unless_exists(:body, "index_recording_studio_support_pages_on_body_trgm")
  end

  def remove_search_indexes
    remove_index_if_exists("index_recording_studio_support_pages_on_body_trgm")
    remove_index_if_exists("index_recording_studio_support_pages_on_title_trgm")
    remove_index_if_exists("index_recording_studio_support_pages_on_search_vector")
  end

  def remove_search_vector_column
    return unless column_exists?(:recording_studio_support_pages, :search_vector)

    remove_column :recording_studio_support_pages, :search_vector
  end

  def add_gin_index_unless_exists(column, name)
    return if index_name_exists?(:recording_studio_support_pages, name)

    add_index :recording_studio_support_pages, column, using: :gin, name: name
  end

  def add_trgm_index_unless_exists(column, name)
    return if index_name_exists?(:recording_studio_support_pages, name)

    add_index :recording_studio_support_pages, column,
              opclass: :gin_trgm_ops,
              using: :gin,
              name: name
  end

  def remove_index_if_exists(name)
    return unless index_name_exists?(:recording_studio_support_pages, name)

    remove_index :recording_studio_support_pages, name: name
  end
end
