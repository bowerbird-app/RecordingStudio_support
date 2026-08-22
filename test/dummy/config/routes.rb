Rails.application.routes.draw do
  devise_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  mount RecordingStudioSupport::Engine, at: "/support"
  mount RecordingStudioPublishable::Engine, at: "/"
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable"
  get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help
  get "/help/sections/:id", to: RecordingStudioSupport::PublicSectionsController.action(:show),
                            as: :public_help_section
  mount RecordingStudioAccessible::Engine, at: "/admin/access"
  recording_studio_admin_for :admin, at: "/admin", root_section: :support

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
