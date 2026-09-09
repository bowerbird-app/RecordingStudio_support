Rails.application.routes.draw do
  devise_options = { skip: %i[sessions registrations passwords] }
  if RecordingStudioUser.config.omniauth_configured?
    devise_options[:controllers] = {
      omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
    }
  end
  devise_for :users, **devise_options

  recording_studio_user_auth_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable"
  get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help
  get "/help/sections/:slug", to: RecordingStudioSupport::PublicSectionsController.action(:show),
                              as: :public_help_section
  mount RecordingStudioPublishable::Engine, at: "/"
  mount RecordingStudioAccessible::Engine, at: "/admin/access"
  mount RecordingStudioSupport::Engine, at: "/admin/support"
  recording_studio_admin_for :admin, at: "/admin", root_section: :support
  get "/support", to: redirect("/admin")
  get "/support/*legacy_support_path", to: redirect("/admin")
  mount RecordingStudioUser::Engine => RecordingStudioUser.config.mount_path, as: :recording_studio_users

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
