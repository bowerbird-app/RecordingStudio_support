# frozen_string_literal: true

RecordingStudioSupport::Engine.routes.draw do
  resources :sections, only: %i[index show new create edit update] do
    member do
      post :trash
    end
  end

  resources :pages, path: "", only: %i[show new create edit update] do
    member do
      post :trash
    end
  end

  root to: "sections#index"
end
