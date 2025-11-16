Scheduling.configure do |config|
  # Organization Settings
  config.organization_name = 'Test Clinic'
  config.organization_slug = 'test-clinic'
  config.organization_timezone = 'America/Lima'
  config.organization_currency = 'PEN'
  config.organization_locale = 'es'

  # Auto-Sync Settings
  config.auto_create_members = true
  config.sync_member_on_user_update = true
  config.auto_create_default_schedule = true
  config.auto_create_default_event_type = true

  # Fallback names
  config.default_location_name = 'Sede Principal'
  config.default_team_name = 'Equipo por defecto'

  # UI Theming
  config.company_name = 'Test Clinic'
  config.logo_url = nil  # Optional - set to a URL to display a logo
  config.primary_color = '#3b82f6'  # Blue
  config.secondary_color = '#6b7280'  # Gray
  config.font_family = 'system-ui, -apple-system, sans-serif'

  # Other settings
  config.default_locale = :es
  config.available_locales = [:es, :en, :pt, :fr]
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']
  config.default_cancellation_hours = 24
  config.send_confirmation_emails = true
end
