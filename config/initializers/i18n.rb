# Load locale files from the engine
I18n.load_path += Dir[Scheduling::Engine.root.join('config', 'locales', '**', '*.{rb,yml}')]

# Set default locale from configuration
I18n.default_locale = Scheduling.configuration.default_locale

# Set available locales from configuration
I18n.available_locales = Scheduling.configuration.available_locales

# Fallback to Spanish if translation is missing
I18n.fallbacks = [:es]
