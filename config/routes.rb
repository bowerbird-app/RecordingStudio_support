# frozen_string_literal: true

RecordingStudioSupport::Engine.routes.draw do
  resources :pages, path: "", only: %i[index show new create edit update] do
    member do
      post :trash
    end
  end
end
