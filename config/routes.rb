# frozen_string_literal: true

RecordingStudioSupport::Engine.routes.draw do
  resource :messages, only: :show, controller: "support_inbox"
  resources :tickets, only: :update, controller: "support_tickets"

  resources :sections, only: %i[index show new create edit update] do
    member do
      get :instant_search, to: "instant_searches#show"
      post :trash
    end
  end

  post "uploads", to: "uploads#create"
  get "icon_preview", to: "icon_previews#show", as: :icon_preview

  resources :pages, path: "", only: %i[show new create edit update] do
    member do
      post :trash
    end
  end

  root to: "sections#index"
end
