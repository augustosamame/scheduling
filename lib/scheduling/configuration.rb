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
                  :enable_whatsapp_notifications,
                  :enable_google_calendar,
                  :enable_outlook_calendar,
                  # Calendar OAuth credentials
                  :google_client_id,
                  :google_client_secret,
                  :microsoft_client_id,
                  :microsoft_client_secret,
                  # Payment gateway credentials
                  :stripe_publishable_key,
                  :stripe_secret_key,
                  :culqi_public_key,
                  :culqi_secret_key,
                  # Twilio credentials
                  :twilio_account_sid,
                  :twilio_auth_token,
                  :twilio_phone_number,
                  :twilio_whatsapp_number,
                  :mailer_from,
                  # Organization defaults
                  :organization_name,
                  :organization_slug,
                  :organization_timezone,
                  :organization_currency,
                  :organization_locale,
                  # Default location/team names (fallbacks)
                  :default_location_name,
                  :default_team_name,
                  # Auto-sync settings
                  :auto_create_members,
                  :sync_member_on_user_update,
                  :auto_create_default_schedule,
                  :auto_create_default_event_type,
                  # UI Theming
                  :logo_url,
                  :company_name,
                  :font_family,
                  :primary_color,
                  :secondary_color

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
      @enable_whatsapp_notifications = false
      @enable_google_calendar = true
      @enable_outlook_calendar = true

      # Calendar OAuth credentials (fallbacks to ENV variables if not set)
      @google_client_id = nil
      @google_client_secret = nil
      @microsoft_client_id = nil
      @microsoft_client_secret = nil

      # Payment gateway credentials (fallbacks to ENV variables if not set)
      @stripe_publishable_key = nil
      @stripe_secret_key = nil
      @culqi_public_key = nil
      @culqi_secret_key = nil

      # Twilio credentials (fallbacks to ENV variables if not set)
      @twilio_account_sid = nil
      @twilio_auth_token = nil
      @twilio_phone_number = nil
      @twilio_whatsapp_number = nil

      @mailer_from = 'noreply@example.com'

      # Organization defaults
      @organization_name = 'My Organization'
      @organization_slug = 'my-organization'
      @organization_timezone = 'America/Lima'
      @organization_currency = 'PEN'
      @organization_locale = 'es'

      # Default location/team names (used when user doesn't have associations)
      @default_location_name = 'Sede Principal'
      @default_team_name = 'Equipo por defecto'

      # Auto-sync settings
      @auto_create_members = true
      @sync_member_on_user_update = true
      @auto_create_default_schedule = true
      @auto_create_default_event_type = true

      # UI Theming defaults
      @logo_url = nil  # Optional - will show company_name if not set
      @company_name = 'Scheduling'  # Fallback name
      @font_family = 'system-ui, -apple-system, sans-serif'
      @primary_color = '#3b82f6'  # Blue
      @secondary_color = '#6b7280'  # Gray
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
