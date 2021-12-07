Rails.application.routes.draw do
  resources :donations
  root 'donations#index'
  post '/confirmation', to: 'donations#webhook'
  get '/mach/:id', to: 'donations#check_donation', as: 'check_donation'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
