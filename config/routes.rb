# frozen_string_literal: true

RecordingStudioSupport::Engine.routes.draw do
  resource :messages, only: :show, controller: "staff_messages"

  resources :sections, only: %i[index show new create edit update] do
    member do
      get :instant_search, to: "instant_searches#show"
      post :trash
    end
  end

  post "uploads", to: "uploads#create"

  resources :pages, path: "", only: %i[show new create edit update] do
    member do
      post :trash
    end
  end

  root to: "sections#index"
end
