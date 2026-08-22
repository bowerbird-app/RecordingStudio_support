# frozen_string_literal: true

require_relative "pages/lookups"

module RecordingStudioSupport
  module Pages
    extend Lookups

    module_function

    SUPPORT_PAGE_TYPE = "RecordingStudioSupport::SupportPage"

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
