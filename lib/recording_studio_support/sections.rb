# frozen_string_literal: true

require_relative "sections/lookups"

module RecordingStudioSupport
  module Sections
    extend Lookups

    module_function

    SUPPORT_SECTION_TYPE = "RecordingStudioSupport::SupportSection"

    def for_root(root_recording, query: nil)
      workspace = parent_root_for(root_recording)
      return RecordingStudio::Recording.none unless workspace

      relation = kept_sections(workspace)
      apply_query(relation, query).preload(:recordable)
    end

    def public_index(query: nil)
      apply_query(kept, query).preload(:recordable)
    end

    def kept
      RecordingStudio::Recording.where(
        recordable_type: SUPPORT_SECTION_TYPE,
        trashed_at: nil
      )
    end

    def create!(root_recording:, title:, actor: nil)
      workspace = parent_root_for(root_recording)
      raise ArgumentError, "Help sections belong under a workspace." if workspace.blank?

      assign_actor(actor) do
        workspace.record(SupportSection) do |section|
          section.title = title.to_s.strip
        end
      end
    end

    def revise!(recording:, title:, actor: nil)
      assign_actor(actor) do
        recording.root_recording.revise(recording) do |section|
          section.title = title.to_s.strip
        end
      end
    end

    def trash!(recording:, actor: nil)
      assign_actor(actor) do
        recording.recording_studio_trashable_trash!(actor: actor || Current.actor)
      end
    end

    def apply_query(relation, query)
      term = query.to_s.strip
      return ordered(relation) if term.blank?

      pattern = Pages.page_query_pattern(term)
      relation.joins(section_join_sql).where(
        "recording_studio_support_sections.title ILIKE :q",
        q: pattern
      )
    end

    def ordered(relation)
      if relation.klass.column_names.include?("recording_studio_orderable_position")
        return relation.order(:recording_studio_orderable_position, :created_at)
      end

      relation.order(:created_at)
    end

    def section_join_sql
      table = RecordingStudio::Recording.table_name
      type = ActiveRecord::Base.connection.quote(SUPPORT_SECTION_TYPE)
      "INNER JOIN recording_studio_support_sections " \
        "ON recording_studio_support_sections.id = #{table}.recordable_id " \
        "AND #{table}.recordable_type = #{type}"
    end

    def kept_sections(root_recording)
      RecordingStudio::Recording.where(
        root_recording_id: root_recording.id,
        parent_recording_id: root_recording.id,
        recordable_type: SUPPORT_SECTION_TYPE,
        trashed_at: nil
      )
    end

    def assign_actor(actor)
      return yield if actor.nil? || !defined?(Current)

      previous = Current.actor
      Current.actor = actor
      yield
    ensure
      Current.actor = previous if defined?(Current) && !actor.nil?
    end
  end
end
