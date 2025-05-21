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
      resources :categories do
        # Add a nested route to get transactions for a specific category
        member do
          get :financial_transactions
        end
      end

      # Budget routes
      resources :budgets

      get '/transactions/summary', to: 'transactions#summary'
      get '/transactions/statistics', to: 'transactions#statistics'

      get 'financial_health', to: 'financial_health#index'
      get 'financial_health/current_month', to: 'financial_health#index', defaults: { range: 'current_month' }
      get 'financial_health/last_3_months', to: 'financial_health#index', defaults: { range: 'last_90_days' }
      get 'financial_health/year_to_date', to: 'financial_health#index', defaults: { range: 'year_to_date' }

      namespace :reports do
        # Main report endpoints with date range support
        get 'summary', to: 'reports#summary'
        get 'income_expense', to: 'reports#income_expense_analysis'
        get 'category_breakdown', to: 'reports#category_spending_breakdown'

        # Convenience endpoints for common ranges
        get 'summary/current_month', to: 'reports#summary', defaults: { range: 'current_month' }
        get 'summary/previous_month', to: 'reports#summary', defaults: { range: 'previous_month' }
        get 'summary/last_30_days', to: 'reports#summary', defaults: { range: 'last_30_days' }
        get 'summary/year_to_date', to: 'reports#summary', defaults: { range: 'year_to_date' }
        # Similar convenience routes for other report types...

        # Trends with date range support
        get 'trends/spending', to: 'trends#spending'
        get 'trends/income', to: 'trends#income'
        # More trend endpoints...

        # Specific date format routes (optional)
        get 'summary/:year/:month', to: 'reports#summary_by_month'
        get 'summary/:year/:quarter', to: 'reports#summary_by_quarter'
        get 'summary/:year', to: 'reports#summary_by_year'

        get 'savings_rate', to: 'reports#savings_rate_analysis'
        get 'savings_rate/current_month', to: 'reports#savings_rate_analysis', defaults: { range: 'current_month' }
        get 'savings_rate/year_to_date', to: 'reports#savings_rate_analysis', defaults: { range: 'year_to_date' }
        get 'savings_rate/last_12_months', to: 'reports#savings_rate_analysis', defaults: { range: 'last_12_months' }
      end

      namespace :trends do
        get 'spending', to: 'trends#spending'
        get 'income', to: 'trends#income'
        get 'savings_rate', to: 'trends#savings_rate'
        get 'category/:id', to: 'trends#category_trend'
        get 'budget_adherence', to: 'trends#budget_adherence'

        # Comparison endpoints
        get 'month_comparison/:year1/:month1/:year2/:month2', to: 'trends#month_comparison'
        get 'year_comparison/:year1/:year2', to: 'trends#year_comparison'
      end

      resources :financial_goals do
        member do
          get :contributions
          post :contributions, to: 'financial_goals#add_contribution'
          post :categories, to: 'financial_goals#add_category'
          delete 'categories/:category_id', to: 'financial_goals#remove_category'
          get :projection
        end

        collection do
          get :dashboard
          get :stats
        end
      end

      # Tags routes
      resources :tags
      post 'financial_transactions/:transaction_id/tags', to: 'tags#tag_transaction'

      # Update existing financial transactions routes to include tagging
      resources :financial_transactions do
        # Existing routes...

        # Add tagging endpoints
        member do
          get :tags
          post :tags, to: 'tags#tag_transaction'
        end
      end

      resources :categories do
        member do
          get 'financial_transactions'
          get 'financial_goals' # New route
        end
      end

      resources :notifications, only: [:index, :show] do
        member do
          patch :mark_as_read
          patch :archive
        end

        collection do
          post :mark_all_as_read
          get :unread_count
        end
      end

      # Notification preferences
      resources :notification_preferences, only: [:index, :update] do
        collection do
          post :update_all
        end
      end
    end
  end
end
