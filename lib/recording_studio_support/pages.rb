# frozen_string_literal: true

require_relative "pages/lookups"

module RecordingStudioSupport
  module Pages
    extend Lookups

    module_function

    SUPPORT_PAGE_TYPE = "RecordingStudioSupport::SupportPage"

    def for_root(root_recording, query: nil)
      workspace = Sections.parent_root_for(root_recording)
      return RecordingStudio::Recording.none unless workspace

      apply_query(kept_pages(workspace), query).preload(:recordable)
    end

    def for_section(section_recording, query: nil)
      return RecordingStudio::Recording.none unless section_recording

      if query.to_s.strip.blank? && section_recording.respond_to?(:recording_studio_orderable_children)
        return section_recording.recording_studio_orderable_children.preload(:recordable)
      end

      apply_query(kept_pages_for_section(section_recording), query).preload(:recordable)
    end

    def public_indexable(query: nil)
      apply_page_query(SupportPage.indexable, query).distinct.order(:title)
    end

    def public_for_section(section_recording, query: nil)
      return SupportPage.none unless section_recording

      page_ids = kept_pages_for_section(section_recording).pluck(:recordable_id)
      apply_page_query(SupportPage.indexable.where(id: page_ids), query).distinct.order(:title)
    end

    def find_for_root!(root_recording:, id:)
      workspace = Sections.parent_root_for(root_recording)
      kept_pages(workspace).includes(:recordable).find(id)
    end

    def create!(parent_recording:, title:, body:, actor: nil)
      assign_actor(actor) do
        parent_recording.root_recording.record(
          SupportPage,
          parent_recording: parent_recording
        ) do |page|
          page.title = title.to_s.strip
          page.body = Body.sanitize(body)
        end
      end
    end

    def revise!(recording:, title:, body:, actor: nil)
      assign_actor(actor) do
        recording.root_recording.revise(recording) do |page|
          page.title = title.to_s.strip
          page.body = Body.sanitize(body)
        end
      end
    end

    def trash!(recording:, actor: nil)
      assign_actor(actor) do
        recording.recording_studio_trashable_trash!(actor: actor || Current.actor)
      end
    end

    def move!(recording:, parent_recording:, actor: nil)
      assign_actor(actor) do
        recording.move_to!(
          new_parent: parent_recording,
          actor: actor || Current.actor
        )
      end
      recording.reload
    end

    def recording_for(page)
      RecordingStudio::Recording.find_by(
        recordable: page,
        recordable_type: SUPPORT_PAGE_TYPE,
        trashed_at: nil
      )
    end

    def apply_query(relation, query)
      term = query.to_s.strip
      return relation if term.blank?

      pattern = page_query_pattern(term)
      relation.joins(support_page_join_sql).where(
        "recording_studio_support_pages.title ILIKE :q OR recording_studio_support_pages.body ILIKE :q",
        q: pattern
      )
    end

    def apply_page_query(relation, query)
      term = query.to_s.strip
      return relation if term.blank?

      table = SupportPage.table_name
      relation.where(
        "#{table}.title ILIKE :q OR #{table}.body ILIKE :q",
        q: page_query_pattern(term)
      )
    end

    def page_query_pattern(term)
      "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    end

    def support_page_join_sql
      table = RecordingStudio::Recording.table_name
      type = ActiveRecord::Base.connection.quote(SUPPORT_PAGE_TYPE)
      "INNER JOIN recording_studio_support_pages " \
        "ON recording_studio_support_pages.id = #{table}.recordable_id " \
        "AND #{table}.recordable_type = #{type}"
    end

    def kept_pages(root_recording)
      RecordingStudio::Recording.where(
        root_recording_id: root_recording.id,
        recordable_type: SUPPORT_PAGE_TYPE,
        trashed_at: nil
      )
    end

    def kept_pages_for_section(section_recording)
      RecordingStudio::Recording.where(
        parent_recording_id: section_recording.id,
        recordable_type: SUPPORT_PAGE_TYPE,
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
