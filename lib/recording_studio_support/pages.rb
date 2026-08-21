# frozen_string_literal: true

module RecordingStudioSupport
  module Pages
    module_function

    SUPPORT_PAGE_TYPE = "RecordingStudioSupport::SupportPage"

    def for_root(root_recording)
      return RecordingStudio::Recording.none unless root_recording

      kept_pages(root_recording).includes(:recordable).order(created_at: :desc)
    end

    def find_for_root!(root_recording:, id:)
      kept_pages(root_recording).includes(:recordable).find(id)
    end

    def create!(root_recording:, title:, body:, actor: nil)
      assign_actor(actor) do
        root_recording.record(SupportPage) do |page|
          page.title = title.to_s.strip
          page.body = body
        end
      end
    end

    def revise!(recording:, title:, body:, actor: nil)
      assign_actor(actor) do
        recording.root_recording.revise(recording) do |page|
          page.title = title.to_s.strip
          page.body = body
        end
      end
    end

    def trash!(recording:, actor: nil)
      assign_actor(actor) do
        recording.recording_studio_trashable_trash!(actor: actor || Current.actor)
      end
    end

    def recording_for(page)
      RecordingStudio::Recording.find_by(
        recordable: page,
        recordable_type: SUPPORT_PAGE_TYPE,
        trashed_at: nil
      )
    end

    def kept_pages(root_recording)
      relation = RecordingStudio::Recording.where(
        root_recording_id: root_recording.id,
        parent_recording_id: root_recording.id,
        recordable_type: SUPPORT_PAGE_TYPE
      )
      relation.where(trashed_at: nil)
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
