class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Users gem sign-in/sign-up use layouts/recording_studio_user/auth.
  # Remaining Devise screens keep layouts/application. A nil setting falls
  # through to RecordingStudio.configuration.layout, then the core default.
  recording_studio_layout { devise_controller? ? "application" : nil }

  before_action :authenticate_user!
  before_action :set_current_actor

  helper_method :current_recording

  # Views' default recording_resolver reads this. Publishable public help
  # renders on Publishable's controller, which sets @parent_recording/@recording.
  def current_recording
    @current_recording || @page_recording || @parent_recording || @recording
  end

  private

  def set_current_actor
    Current.actor = current_user
  end
end
