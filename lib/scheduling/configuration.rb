module Scheduling
  class Configuration
    attr_accessor :enable_multi_tenancy,
                  :default_locale,
                  :available_locales,
                  :detect_locale_from_browser,
                  :default_currency,
                  :available_currencies,
                  :payment_providers,
                  :default_cancellation_hours,
                  :default_rescheduling_hours,
                  :default_minimum_notice_hours,
                  :send_confirmation_emails,
                  :send_reminder_emails,
                  :reminder_hours_before,
                  :enable_sms_notifications,
                  :enable_google_calendar,
                  :enable_outlook_calendar

    def initialize
      @enable_multi_tenancy = true
      @default_locale = :es
      @available_locales = [:es, :en, :pt, :fr]
      @detect_locale_from_browser = true
      @default_currency = 'PEN'
      @available_currencies = ['PEN', 'USD', 'EUR', 'GBP']
      @payment_providers = [:stripe, :culqi]
      @default_cancellation_hours = 24
      @default_rescheduling_hours = 24
      @default_minimum_notice_hours = 2
      @send_confirmation_emails = true
      @send_reminder_emails = true
      @reminder_hours_before = 24
      @enable_sms_notifications = false
      @enable_google_calendar = true
      @enable_outlook_calendar = true
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
