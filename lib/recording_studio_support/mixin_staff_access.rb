# frozen_string_literal: true

module RecordingStudioSupport
  # Trashable checks Accessible on the page/section. Support writes are gated on
  # AdminRoot :edit (same as authorize_support!(:edit)). Compose that check into
  # Trashable's public authorization_resolver so Pages.trash! / Sections.trash!
  # keep working for an operations API client that only has AdminRoot access.
  module MixinStaffAccess
    module_function

    SUPPORT_TYPES = [
      "RecordingStudioSupport::SupportPage",
      "RecordingStudioSupport::SupportSection"
    ].freeze

    def install!
      install_trashable!
    end

    def install_trashable!
      return unless defined?(RecordingStudioTrashable)

      configuration = RecordingStudioTrashable.configuration
      current = configuration.authorization_resolver
      return if current.equal?(method(:authorize_trash))

      @previous_trashable = current
      configuration.authorization_resolver = method(:authorize_trash)
    end

    def authorize_trash(**payload)
      recording = payload[:recording]
      actor = payload[:actor]
      return true if support_recording?(recording) && admin_root_edit?(actor)

      previous = @previous_trashable
      return nil unless previous.respond_to?(:call)

      previous.call(**payload)
    end

    def support_recording?(recording)
      SUPPORT_TYPES.include?(recording&.recordable_type.to_s)
    end

    def admin_root_edit?(actor)
      recording = Api::Access.admin_root_recording
      return false if actor.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: :edit
      )
    end
  end
end
