# Culqi Payment Gateway Configuration
class Culqi
  class << self
    def public_key
      key = ENV["CULQI_PUBLIC_KEY"] || Scheduling.configuration.culqi_public_key

      # If no key configured, use test key with warning
      if key.blank?
        Rails.logger.warn "Culqi public key not configured. Using test key."
        "pk_test_xJxYeWsMdLljGBwo"
      else
        key
      end
    end

    def secret_key
      key = ENV["CULQI_SECRET_KEY"] || Scheduling.configuration.culqi_secret_key

      # If no key configured, use test key with warning
      if key.blank?
        Rails.logger.warn "Culqi secret key not configured. Using test key."
        "sk_test_ARS0TByIPr4tLLxm"
      else
        key
      end
    end

    def base_url
      "https://api.culqi.com"
    end

    def checkout_url
      "https://checkout.culqi.com"
    end

    def configured?
      (ENV["CULQI_PUBLIC_KEY"].present? && ENV["CULQI_SECRET_KEY"].present?) ||
      (Scheduling.configuration.culqi_public_key.present? && Scheduling.configuration.culqi_secret_key.present?)
    end
  end
end

# Log configuration status
Rails.application.config.after_initialize do
  if Culqi.configured?
    Rails.logger.info "Culqi payment gateway configured"
  else
    Rails.logger.warn "Culqi payment gateway not configured. Using test keys. Set CULQI_PUBLIC_KEY and CULQI_SECRET_KEY environment variables."
  end
end
