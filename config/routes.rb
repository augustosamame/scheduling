Scheduling::Engine.routes.draw do
  # Public booking pages (customer-facing)
  scope '/:organization_slug' do
    # Member's booking page - shows all event types for a member
    get '/:booking_slug', to: 'public_bookings#index', as: :member_booking

    # Book a specific event type
    get '/:booking_slug/:event_slug/book', to: 'public_bookings#new', as: :new_booking
    post '/:booking_slug/:event_slug/book', to: 'public_bookings#create', as: :create_booking

    # AJAX endpoint for checking availability
    get '/:booking_slug/:event_slug/availability', to: 'public_bookings#availability', as: :booking_availability
  end

  # Booking management with tokens (no authentication required)
  scope '/bookings' do
    get '/:uid', to: 'public_bookings#show', as: :booking_confirmation

    # Cancel booking
    get '/:token/cancel', to: 'public_bookings#cancel', as: :cancel_booking
    post '/:token/cancel', to: 'public_bookings#process_cancellation', as: :process_cancel_booking

    # Reschedule booking
    get '/:token/reschedule', to: 'public_bookings#reschedule', as: :reschedule_booking
    post '/:token/reschedule', to: 'public_bookings#process_reschedule', as: :process_reschedule_booking
  end
end
