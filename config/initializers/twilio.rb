# Twilio initialization for SMS and WhatsApp notifications
#
# This initializer checks if Twilio is available and properly configured.
# It does not raise errors if Twilio is not configured, allowing the engine
# to work without SMS/WhatsApp functionality.

if defined?(Twilio)
  Rails.logger.info "Twilio gem detected - SMS and WhatsApp notifications available"

  # Check if credentials are configured
  account_sid = ENV['TWILIO_ACCOUNT_SID'] || Scheduling.configuration.twilio_account_sid
  auth_token = ENV['TWILIO_AUTH_TOKEN'] || Scheduling.configuration.twilio_auth_token
  phone_number = ENV['TWILIO_PHONE_NUMBER'] || Scheduling.configuration.twilio_phone_number
  whatsapp_number = ENV['TWILIO_WHATSAPP_NUMBER'] || Scheduling.configuration.twilio_whatsapp_number

  if account_sid.present? && auth_token.present?
    Rails.logger.info "Twilio credentials configured"

    if phone_number.present?
      Rails.logger.info "Twilio SMS enabled with number: #{phone_number}"
    else
      Rails.logger.warn "Twilio phone number not configured - SMS notifications disabled"
    end

    if whatsapp_number.present?
      Rails.logger.info "Twilio WhatsApp enabled with number: #{whatsapp_number}"
    else
      Rails.logger.warn "Twilio WhatsApp number not configured - WhatsApp notifications disabled"
    end

    # Test the connection in development (optional)
    if Rails.env.development? && ENV['TWILIO_TEST_CONNECTION'] == 'true'
      begin
        client = Twilio::REST::Client.new(account_sid, auth_token)
        client.api.accounts(account_sid).fetch
        Rails.logger.info "✅ Twilio connection test successful"
      rescue Twilio::REST::RestError => e
        Rails.logger.error "❌ Twilio connection test failed: #{e.message}"
      end
    end
  else
    Rails.logger.info "Twilio credentials not configured - SMS/WhatsApp disabled"
  end
else
  Rails.logger.info "Twilio gem not installed - SMS and WhatsApp notifications unavailable"
  Rails.logger.info "Add 'gem \"twilio-ruby\"' to your Gemfile to enable Twilio notifications"
end

# Helper method to check if Twilio is available
module Scheduling
  class Configuration
    def twilio_available?
      return false unless defined?(Twilio)

      account_sid = ENV['TWILIO_ACCOUNT_SID'] || twilio_account_sid
      auth_token = ENV['TWILIO_AUTH_TOKEN'] || twilio_auth_token

      account_sid.present? && auth_token.present?
    end

    def sms_available?
      enable_sms_notifications && twilio_available? &&
        (ENV['TWILIO_PHONE_NUMBER'].present? || twilio_phone_number.present?)
    end

    def whatsapp_available?
      enable_whatsapp_notifications && twilio_available? &&
        (ENV['TWILIO_WHATSAPP_NUMBER'].present? || twilio_whatsapp_number.present?)
    end
  end
end
