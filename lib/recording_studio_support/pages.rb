# frozen_string_literal: true

require_relative "pages/lookups"
require_relative "pages/counts"

module RecordingStudioSupport
  module Pages
    extend Lookups
    extend Counts

    module_function

    SUPPORT_PAGE_TYPE = "RecordingStudioSupport::SupportPage"

    # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength -- public write API keeps optional fields explicit
    def create!(parent_recording:, title:, body:, description: nil, icon: nil, actor: nil)
      assign_actor(actor) do
        parent_recording.root_recording.record(
          SupportPage,
          parent_recording: parent_recording
        ) do |page|
          page.title = title.to_s.strip
          page.description = description.to_s.strip.presence
          page.icon = icon
          page.body = Body.sanitize(body)
        end
      end
    end

    def revise!(recording:, title:, body:, description: nil, icon: nil, actor: nil)
      assign_actor(actor) do
        recording.root_recording.revise(recording) do |page|
          page.title = title.to_s.strip
          page.description = description.to_s.strip.presence
          page.icon = icon
          page.body = Body.sanitize(body)
        end
      end
    end
    # rubocop:enable Metrics/ParameterLists, Metrics/MethodLength

    def trash!(recording:, actor: nil)
      assign_actor(actor) do
        recording.recording_studio_trashable_trash!(actor: actor || Current.actor)
      end
    end

    def move!(recording:, parent_recording:, actor: nil)
      resolved = actor || (defined?(Current) && Current.actor)
      assign_actor(resolved) do
        apply_move!(recording, parent_recording, resolved)
      end
      recording.reload
    end

    def apply_move!(recording, parent_recording, resolved)
      if staff_move_without_tree_acl?(resolved, recording, parent_recording)
        staff_move!(recording, parent_recording, resolved)
      else
        recording.move_to!(new_parent: parent_recording, actor: resolved)
      end
    end

    def staff_move_without_tree_acl?(resolved, recording, parent_recording)
      MixinStaffAccess.admin_root_edit?(resolved) &&
        !(mixin_tree_edit?(resolved, recording) && mixin_tree_edit?(resolved, parent_recording))
    end

    def assign_actor(actor)
      return yield if actor.nil? || !defined?(Current)

      previous = Current.actor
      Current.actor = actor
      yield
    ensure
      Current.actor = previous if defined?(Current) && !actor.nil?
    end

    def mixin_tree_edit?(actor, recording)
      return false if actor.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: :edit
      )
    end

    def staff_move!(recording, parent_recording, actor)
      RecordingStudio.assert_parent_allowed!(
        child_type: recording.recordable_type,
        parent_recording: parent_recording
      )
      recording.log_event!(
        action: "moved",
        actor: actor,
        metadata: { from_parent_id: recording.parent_recording_id, to_parent_id: parent_recording.id }
      )
      recording.update!(parent_recording_id: parent_recording.id)
    end
  end
end
