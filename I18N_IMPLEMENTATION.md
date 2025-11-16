# I18n Implementation Summary

## Overview

The Scheduling engine now has full internationalization (I18n) support with 4 languages and automatic locale detection from browser settings.

## Supported Languages

- **Spanish (es)** - Default and fallback language
- **English (en)**
- **Portuguese (pt)**
- **French (fr)**

## Configuration

### Engine Configuration

Located in `lib/scheduling/configuration.rb`:

```ruby
@default_locale = :es
@available_locales = [:es, :en, :pt, :fr]
@detect_locale_from_browser = true
```

### Host App Configuration

In your initializer `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  # Locale settings
  config.default_locale = :es  # Can be changed to :en, :pt, or :fr
  config.available_locales = [:es, :en, :pt, :fr]
  config.detect_locale_from_browser = true
end
```

## How It Works

### 1. Session-Based Locale Persistence

The locale selection is automatically saved to the user's session and persists across page refreshes and navigation.

**Priority Order:**
1. **URL parameter** (`?locale=xx`) - Explicitly set by user, saves to session
2. **Session stored locale** - Previously selected language
3. **Browser detected locale** - Auto-detected from `Accept-Language` header (if enabled)
4. **Default locale** - From configuration (`:es`)

**Implementation in `PublicBookingsController`:**

```ruby
def set_locale
  if params[:locale].present?
    # User explicitly selected a locale via URL parameter
    locale = params[:locale].to_sym
    if Scheduling.configuration.available_locales.include?(locale)
      session[:locale] = locale  # Save to session
      I18n.locale = locale
    end
  elsif session[:locale].present?
    # Use previously stored locale from session
    I18n.locale = session[:locale]
  elsif Scheduling.configuration.detect_locale_from_browser
    # Detect from browser and save to session
    browser_locale = extract_locale_from_accept_language_header
    locale = browser_locale&.to_sym || Scheduling.configuration.default_locale
    session[:locale] = locale  # Save to session
    I18n.locale = locale
  else
    # Use default locale and save to session
    session[:locale] = Scheduling.configuration.default_locale
    I18n.locale = Scheduling.configuration.default_locale
  end
end
```

### 2. Fallback System

If a translation is missing in the selected language, it falls back to Spanish (:es):

```ruby
# config/initializers/i18n.rb
I18n.fallbacks = [:es]
```

### 3. URL Parameter Override with Session Persistence

Users can set their language preference using a URL parameter, and it will be saved to their session:

```
/book/clinic/dr-smith/consultation?locale=en
```

**How it works:**
- User visits with `?locale=en` → Locale set to English and saved to session
- User navigates to another page → Still in English (from session)
- User clicks "Siguiente" → Still in English (from session)
- User refreshes page → Still in English (from session)
- Session persists until browser closes or user selects a different language

## Translation Files

All translation files are located in `config/locales/`:

- `es.yml` - Spanish (España/Latinoamérica)
- `en.yml` - English
- `pt.yml` - Portuguese (Brasil)
- `fr.yml` - French

## Translation Keys Structure

```yaml
scheduling:
  bookings:
    index:
      title: "Book with %{member_name}"
      available_types: "Available Appointment Types"
    new:
      select_datetime: "Select a date and time"
      next: "Next"
      back: "Back"
      confirm_booking: "Confirm Booking"

  forms:
    first_name: "First Name"
    last_name: "Last Name"
    email: "Email"

  event_types:
    duration: "%{minutes} min"
    free: "FREE"
    book_now: "Book Now"

  calendar:
    days_short:
      sun: "SUN"
      mon: "MON"
      # ...

  errors:
    booking_not_found: "Booking not found"
    past_cancellation_deadline: "Cannot cancel..."
```

## Usage in Views

### Simple Translation

```erb
<h3><%= t('scheduling.bookings.new.select_datetime') %></h3>
```

### Translation with Interpolation

```erb
<%= t('scheduling.event_types.duration', minutes: event_type.duration_minutes) %>
```

### Translation in Forms

```erb
<label>
  <%= t('scheduling.forms.first_name') %> <%= t('scheduling.forms.required') %>
</label>
```

## Translated Components

### Public Booking Flow

- ✅ Event types listing page
- ✅ Booking form (date/time selection)
- ✅ User details form
- ✅ Calendar day headers
- ✅ All form labels and buttons
- ✅ Error messages
- ✅ Success/confirmation messages

### Controller Flash Messages

- ✅ Cancellation success/error
- ✅ Rescheduling success/error
- ✅ Policy violation messages

### Future Components (Ready for Use)

Translation keys are already defined for:

- Email notifications (confirmation, reminder, cancellation, reschedule)
- Payment messages
- Location types (in-person, video call, phone call)

## Adding New Languages

To add a new language (e.g., German):

1. Add to available locales in configuration:
   ```ruby
   config.available_locales = [:es, :en, :pt, :fr, :de]
   ```

2. Create translation file:
   ```bash
   cp config/locales/en.yml config/locales/de.yml
   ```

3. Translate all strings in the new file

4. Restart the server

## Testing Different Locales

### Via Browser Settings

Change your browser's language preferences to test automatic detection.

### Via URL Parameter (Recommended)

Set the language once, and it persists throughout the session:

```bash
# Set to English - will persist across page refreshes
http://localhost:3000/book/test-clinic/dr-maria-rodriguez?locale=en

# Set to Portuguese - will persist across page refreshes
http://localhost:3000/book/test-clinic/dr-maria-rodriguez?locale=pt

# Set to French - will persist across page refreshes
http://localhost:3000/book/test-clinic/dr-maria-rodriguez?locale=fr

# Set to Spanish (default) - will persist across page refreshes
http://localhost:3000/book/test-clinic/dr-maria-rodriguez?locale=es
```

**Testing Session Persistence:**
1. Visit: `http://localhost:3000/book/test-clinic/dr-maria-rodriguez?locale=en`
2. Navigate to another page (click on an event type)
3. Notice the language is still English (no `?locale=en` needed)
4. Refresh the page - still English!
5. Close browser and reopen - back to default (session cleared)

### Via Configuration

Change the default in your initializer:

```ruby
config.default_locale = :en  # English as default
```

### Clear Session Locale

To reset the language preference, either:
- Close and reopen your browser (clears session)
- Visit with a different `?locale=xx` parameter
- Clear your browser cookies

## Best Practices

1. **Always use translation keys** - Never hardcode text in views
2. **Use interpolation** for dynamic values: `%{variable_name}`
3. **Keep keys organized** - Follow the namespace structure
4. **Test all locales** - Ensure all translations are present
5. **Use fallbacks** - Spanish is the fallback language

## Date and Time Formatting

Each locale has custom date/time formats defined:

```yaml
time:
  formats:
    booking: "%A, %B %d at %I:%M %p"  # English
    booking: "%A, %d de %B a las %H:%M"  # Spanish
```

## Related Files

- `config/locales/*.yml` - Translation files
- `config/initializers/i18n.rb` - I18n configuration
- `lib/scheduling/configuration.rb` - Engine configuration
- `app/controllers/scheduling/public_bookings_controller.rb` - Locale detection
- `app/views/scheduling/public_bookings/*.html.erb` - Translated views

## Migration Guide

If you have existing views with hardcoded text, replace:

```erb
<!-- Before -->
<h3>Selecciona una fecha y hora</h3>

<!-- After -->
<h3><%= t('scheduling.bookings.new.select_datetime') %></h3>
```

## Notes

- **Default locale**: Spanish (:es)
- **Fallback locale**: Spanish (:es)
- **Browser detection**: Enabled by default
- **URL override**: Supported via `?locale=xx` parameter
- **All views**: Fully translated (100% coverage)
- **Email templates**: Translation keys ready, templates not yet implemented
