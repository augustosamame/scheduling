Rails.application.routes.draw do
  # Mount at /book to mirror real-world usage
  # This avoids route conflicts with main app routes
  mount Scheduling::Engine => "/book"
end
