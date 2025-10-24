Rails.application.routes.draw do
  mount Scheduling::Engine => "/scheduling"
end
