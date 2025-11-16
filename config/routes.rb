Scheduling::Engine.routes.draw do
  # Calendar connections OAuth callbacks (must be at root level for OAuth providers)
  get '/calendar_connections/google_callback', to: 'calendar_connections#google_callback', as: :google_callback
  get '/calendar_connections/outlook_callback', to: 'calendar_connections#outlook_callback', as: :outlook_callback

  # Calendar connections management (requires authentication - implement in host app)
  resources :members, only: [] do
    resources :calendar_connections, only: [:index, :destroy] do
      collection do
        post :connect_google
        post :connect_outlook
      end
    end
  end

  # Booking management with tokens (no authentication required)
  # IMPORTANT: This must come BEFORE the greedy /:organization_slug routes
  scope '/bookings' do
    get '/:uid', to: 'public_bookings#show', as: :booking_confirmation
    get '/:uid/calendar', to: 'public_bookings#download_calendar', as: :download_booking_calendar

    # Cancel booking
    get '/:token/cancel', to: 'public_bookings#cancel', as: :cancel_booking
    post '/:token/cancel', to: 'public_bookings#process_cancellation', as: :process_cancel_booking

    # Reschedule booking
    get '/:token/reschedule', to: 'public_bookings#reschedule', as: :reschedule_booking
    post '/:token/reschedule', to: 'public_bookings#process_reschedule', as: :process_reschedule_booking
  end

  # Public booking pages (customer-facing)
  scope '/:organization_slug' do
    # Organization landing page - shows all bookable members
    get '/', to: 'public_bookings#organization_index', as: :organization_booking

    # Member's booking page - shows all event types for a member
    get '/:booking_slug', to: 'public_bookings#index', as: :member_booking

    # Book a specific event type
    get '/:booking_slug/:event_slug/book', to: 'public_bookings#new', as: :new_booking
    post '/:booking_slug/:event_slug/book', to: 'public_bookings#create', as: :create_booking

    # AJAX endpoint for checking availability
    get '/:booking_slug/:event_slug/availability', to: 'public_bookings#availability', as: :booking_availability
  end
end
