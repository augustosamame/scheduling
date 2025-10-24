require 'scheduling/configuration'

Scheduling.configure do |config|
  # Organization settings
  config.enable_multi_tenancy = true

  # I18n
  config.default_locale = :es
  config.available_locales = [:es, :en, :pt, :fr]
  config.detect_locale_from_browser = true

  # Currency
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']

  # Payment providers
  config.payment_providers = [:stripe, :culqi]

  # Policies
  config.default_cancellation_hours = 24
  config.default_rescheduling_hours = 24

  # Emails
  config.send_confirmation_emails = true
  config.send_reminder_emails = true
  config.reminder_hours_before = 24

  # Calendar integrations
  config.enable_google_calendar = true
  config.enable_outlook_calendar = true
end
