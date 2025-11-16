# Payment Gateway Initialization
# This initializer sets up Stripe and Culqi payment gateways if their gems are available

Rails.application.config.after_initialize do
  # Initialize Stripe if gem is available
  if defined?(Stripe)
    stripe_key = ENV['STRIPE_SECRET_KEY'] ||
                 Scheduling.configuration.stripe_secret_key

    if stripe_key.present?
      Stripe.api_key = stripe_key
      Rails.logger.info "Stripe payment gateway initialized"
    else
      Rails.logger.warn "Stripe gem loaded but no API key configured. Set STRIPE_SECRET_KEY environment variable or configure in scheduling.rb"
    end
  end

  # Initialize Culqi if gem is available
  if defined?(Culqi)
    culqi_secret = ENV['CULQI_SECRET_KEY'] ||
                   Scheduling.configuration.culqi_secret_key

    if culqi_secret.present?
      Culqi.secret_key = culqi_secret
      Rails.logger.info "Culqi payment gateway initialized"
    else
      Rails.logger.warn "Culqi gem loaded but no API key configured. Set CULQI_SECRET_KEY environment variable or configure in scheduling.rb"
    end
  end
end
