Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Versioned from the start: the Next.js apps in Phase 5 pin to v1, so a
  # breaking change later is a new namespace rather than a coordinated deploy.
  namespace :api do
    namespace :v1 do
      resources :employees, only: [ :index, :show ] do
        # Dry run — tells you the answer without recording a request.
        post :eligibility_check, to: "eligibility_checks#create"
        get :ledger, to: "ledger#show"
      end

      resources :advances, only: [ :index, :show, :create ]

      get "ledger/summary", to: "ledger#summary"
      post "payroll_runs/reconcile", to: "reconciliations#create"
    end
  end
end
