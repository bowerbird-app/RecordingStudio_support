# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = ["User", "RecordingStudioApi::ApiClient"]
  # Site-wide admin screens (Support's blast radius) need this root.
  config.admin_root_resolver = lambda do
    admin_root = AdminRoot.find_by(name: "Admin")
    return unless admin_root

    RecordingStudio::Recording.kept.find_by(recordable: admin_root)
  end
  # Accessible 0.36 raises on manage access until the host names who can be granted.
  config.access_management_actor_scope = ->(_controller) { User.order(:email) }
  config.action_audiences[:"recording_studio_views.view"] = {
    allowed: %i[public signed_in granted],
    default: :public,
    granted_roles: %i[view edit admin],
    manage_role: :admin
  }
end
