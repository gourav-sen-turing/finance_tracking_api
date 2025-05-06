Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      # Authentication routes
      namespace :auth do
        post 'login', to: 'authentication#authenticate'
        post 'signup', to: 'users#create'
        post 'logout', to: 'authentication#logout'

        scope :password do
          post 'forgot', to: 'passwords#forgot'
          post 'reset', to: 'passwords#reset'
        end
      end

      # User routes
      resources :users, only: [:show, :update, :destroy] do
        collection do
          get 'me', to: 'users#me'
        end
      end

      # Transaction routes
      resources :transactions

      # Category routes
      resources :categories

      # Budget routes
      resources :budgets

      get '/transactions/summary', to: 'transactions#summary'
      get '/transactions/statistics', to: 'transactions#statistics'
    end
  end
end
