# Calendar Integration Guide

This guide explains calendar integration options for the Scheduling engine.

## Overview

The Scheduling engine offers **two approaches** to calendar integration:

### 1. ICS Files (Simple - No Setup Required) ✅ RECOMMENDED FOR CLIENTS

**Works out of the box** with zero configuration:
- **Download button**: Clients click "Add to Calendar" on confirmation page
- **Email attachments**: ICS file automatically attached to confirmation emails
- **Universal compatibility**: Works with ALL calendar apps (Google, Outlook, Apple, Yahoo, etc.)
- **No OAuth required**: No API credentials needed
- **One-click import**: Calendar apps automatically recognize and import events

**Best for**: Client-facing bookings, quick deployment

### 2. OAuth Integration (Advanced - For Staff Members)

**Requires OAuth setup** but enables bidirectional sync for staff:
- **Automatic sync**: Bookings automatically appear on member's calendar
- **Automatic updates**: Reschedules and cancellations sync instantly
- **Conflict checking**: System checks external calendars before allowing bookings
- **Token refresh**: OAuth tokens auto-refresh when expired

**Best for**: Staff members who need automatic syncing and conflict prevention

---

## ICS File Integration (Simple)

### ✅ No Setup Required - Works Immediately!

When a booking is confirmed, clients automatically receive the event as an ICS file:

**1. On Confirmation Page:**
- "Add to Calendar" button downloads ICS file
- Works with Google, Outlook, Apple Calendar, and all major calendar apps

**2. In Email:**
- ICS file attached to confirmation and reminder emails
- One-click to add event to calendar

**What's Included:**
- Event title, date, time, timezone
- Location (physical address, video URL, or phone)
- Member and client details
- Booking reference and confirmation link
- 24-hour reminder

**Example URL:**
```
GET /scheduling/bookings/{uid}/calendar
→ Downloads: event-name-20250120.ics
```

No configuration needed - this works immediately after installation!

---

## Table of Contents

1. [ICS Files (above - already working!)](#ics-file-integration-simple)
2. [Google Calendar Setup (OAuth)](#google-calendar-setup)
3. [Microsoft Outlook Setup (OAuth)](#microsoft-outlook-setup)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [Troubleshooting](#troubleshooting)

---

## Google Calendar Setup

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Calendar API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Calendar API"
   - Click "Enable"

### Step 2: Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Configure the OAuth consent screen if you haven't already:
   - User Type: External (for public apps) or Internal (for G Workspace only)
   - App name: Your application name
   - User support email: Your email
   - Authorized domains: Your domain (e.g., `example.com`)
   - Developer contact email: Your email
   - Scopes: Add `https://www.googleapis.com/auth/calendar` scope
4. Create OAuth Client ID:
   - Application type: **Web application**
   - Name: "Scheduling Engine - Google Calendar"
   - Authorized JavaScript origins:
     - `http://localhost:3000` (for development)
     - `https://yourdomain.com` (for production)
   - Authorized redirect URIs:
     - `http://localhost:3000/scheduling/calendar_connections/google_callback` (development)
     - `https://yourdomain.com/scheduling/calendar_connections/google_callback` (production)
5. Save the **Client ID** and **Client Secret**

### Step 3: Configure Environment Variables

Add to your `.env` file or environment:

```bash
GOOGLE_CALENDAR_CLIENT_ID=your_client_id_here
GOOGLE_CALENDAR_CLIENT_SECRET=your_client_secret_here
```

Or configure in `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  config.google_client_id = 'your_client_id_here'
  config.google_client_secret = 'your_client_secret_here'
end
```

---

## Microsoft Outlook Setup

### Step 1: Register Application in Azure

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" > "App registrations"
3. Click "New registration"
4. Configure your application:
   - Name: "Scheduling Engine - Outlook Calendar"
   - Supported account types: "Accounts in any organizational directory and personal Microsoft accounts"
   - Redirect URI:
     - Platform: **Web**
     - URI: `http://localhost:3000/scheduling/calendar_connections/outlook_callback` (development)
   - Click "Register"

### Step 2: Configure API Permissions

1. In your app registration, go to "API permissions"
2. Click "Add a permission"
3. Select "Microsoft Graph"
4. Select "Delegated permissions"
5. Add these permissions:
   - `Calendars.ReadWrite`
   - `offline_access` (for refresh tokens)
6. Click "Add permissions"
7. Click "Grant admin consent" (if you're an admin)

### Step 3: Create Client Secret

1. Go to "Certificates & secrets"
2. Click "New client secret"
3. Add a description: "Scheduling Engine OAuth"
4. Set expiration (recommended: 24 months)
5. Click "Add"
6. **Copy the secret value immediately** (you won't be able to see it again)

### Step 4: Add Redirect URIs

1. Go to "Authentication"
2. Under "Platform configurations" > "Web", add redirect URIs:
   - `http://localhost:3000/scheduling/calendar_connections/outlook_callback` (development)
   - `https://yourdomain.com/scheduling/calendar_connections/outlook_callback` (production)
3. Enable "ID tokens" under "Implicit grant and hybrid flows"
4. Save changes

### Step 5: Configure Environment Variables

Add to your `.env` file or environment:

```bash
MICROSOFT_CLIENT_ID=your_application_id_here
MICROSOFT_CLIENT_SECRET=your_client_secret_here
```

Or configure in `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  config.microsoft_client_id = 'your_application_id_here'
  config.microsoft_client_secret = 'your_client_secret_here'
end
```

---

## Configuration

### Initializer Configuration

Create or update `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  # Enable calendar integrations
  config.enable_google_calendar = true
  config.enable_outlook_calendar = true

  # OAuth credentials (optional - will fallback to ENV variables)
  config.google_client_id = ENV['GOOGLE_CALENDAR_CLIENT_ID']
  config.google_client_secret = ENV['GOOGLE_CALENDAR_CLIENT_SECRET']
  config.microsoft_client_id = ENV['MICROSOFT_CLIENT_ID']
  config.microsoft_client_secret = ENV['MICROSOFT_CLIENT_SECRET']
end
```

### Environment Variables (Recommended)

Create a `.env` file in your project root:

```bash
# Google Calendar
GOOGLE_CALENDAR_CLIENT_ID=xxxxxxxxxxxx.apps.googleusercontent.com
GOOGLE_CALENDAR_CLIENT_SECRET=xxxxxxxxxxxxxxxxx

# Microsoft Outlook
MICROSOFT_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MICROSOFT_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Important**: Add `.env` to your `.gitignore` to prevent committing secrets!

---

## Usage

### Member Calendar Connection Flow

1. **Navigate to Calendar Connections Page**:
   ```ruby
   <%= link_to "Calendar Settings",
         scheduling.member_calendar_connections_path(@member) %>
   ```

2. **Connect Google Calendar**:
   - Click "Connect Google Calendar" button
   - User is redirected to Google OAuth consent screen
   - After authorization, user is redirected back with calendar connected
   - Future bookings will automatically sync

3. **Connect Outlook Calendar**:
   - Click "Connect Outlook" button
   - User is redirected to Microsoft login
   - After authorization, user is redirected back with calendar connected
   - Future bookings will automatically sync

4. **Disconnect Calendar**:
   - Click "Disconnect" button on connected calendar
   - Confirms action
   - Stops future syncing (existing events remain in calendar)

### Programmatic Access

```ruby
# Check if member has calendar connected
member = Scheduling::Member.find(1)
member.calendar_connections.active # All active connections

# Sync a booking manually
booking = Scheduling::Booking.find(1)
Scheduling::CalendarSyncJob.perform_later(booking.id, 'create')

# Check for calendar conflicts
connection = member.calendar_connections.google.active.first
service = Scheduling::GoogleCalendarService.new(connection)
has_conflict = service.has_conflicts?(start_time, end_time)

# Refresh expired token
connection.refresh_access_token! if connection.token_expired?
```

### Automatic Syncing

Bookings are automatically synced via callbacks:

```ruby
# In Booking model
after_create :add_to_external_calendar, if: -> { status == 'confirmed' }
after_update :sync_calendar_changes
before_destroy :remove_from_external_calendar
```

The `CalendarSyncJob` handles the actual API calls in the background.

---

## How It Works

### OAuth Flow

1. User clicks "Connect Google Calendar" or "Connect Outlook"
2. Controller generates state token (CSRF protection) and redirects to provider
3. User authorizes the application
4. Provider redirects back to callback URL with authorization code
5. Controller exchanges code for access & refresh tokens
6. Tokens are encrypted and stored in `calendar_connections` table
7. Future API calls use these tokens (auto-refresh if expired)

### Event Syncing

**When a booking is created:**
```ruby
booking = EventType.bookings.create!(...)
# Triggers after_create callback
# CalendarSyncJob.perform_later(booking.id, 'create')
# GoogleCalendarService.new(connection).add_booking(booking)
# Event appears on member's calendar
```

**When a booking is rescheduled:**
```ruby
new_booking = booking.reschedule_to!(new_time)
# Old booking marked as 'rescheduled'
# CalendarSyncJob deletes old event
# CalendarSyncJob creates new event with new time
```

**When a booking is cancelled:**
```ruby
booking.cancel!
# Triggers calendar sync
# CalendarSyncJob.perform_later(booking.id, 'delete')
# Event removed from calendar
```

### Conflict Checking

The `AvailabilityChecker` service optionally checks external calendars:

```ruby
def has_external_calendar_conflicts?(start_time, end_time)
  @member.calendar_connections.active.each do |connection|
    service = connection.provider == 'google' ?
              GoogleCalendarService.new(connection) :
              OutlookCalendarService.new(connection)

    return true if service.has_conflicts?(start_time, end_time)
  end
  false
end
```

---

## Troubleshooting

### Common Issues

#### 1. "Redirect URI mismatch" Error

**Cause**: The redirect URI in your OAuth request doesn't match what's registered.

**Solution**:
- Ensure the redirect URI in Google Cloud Console / Azure Portal exactly matches your callback URL
- Check protocol (http vs https)
- Check domain and path
- For local development: `http://localhost:3000/scheduling/calendar_connections/google_callback`

#### 2. Token Expired Errors

**Cause**: Access tokens expire after a certain time.

**Solution**: The system automatically refreshes tokens, but you can manually trigger:
```ruby
connection.refresh_access_token!
```

#### 3. "Invalid Grant" Error

**Cause**: Refresh token is invalid or revoked.

**Solution**: User needs to disconnect and reconnect the calendar.

#### 4. Calendar Events Not Syncing

**Check these:**
```ruby
# Is the connection active?
connection.active? # Should be true

# Is add_bookings_to_calendar enabled?
connection.add_bookings_to_calendar? # Should be true

# Check background job queue
Solid::Queue.jobs.where(job_class: 'Scheduling::CalendarSyncJob')

# Check logs for errors
tail -f log/development.log | grep "Calendar"
```

#### 5. OAuth Consent Screen Verification

**Issue**: Google may require verification if using sensitive scopes.

**Solution**:
- Submit your app for verification in Google Cloud Console
- Or use "internal" app type if you have G Workspace
- For development, add test users in OAuth consent screen

### Testing Calendar Integration

```ruby
# In Rails console
member = Scheduling::Member.first

# Create a test Google connection
connection = member.calendar_connections.create!(
  provider: 'google',
  access_token: 'test_token',
  refresh_token: 'test_refresh',
  token_expires_at: 1.hour.from_now,
  active: true,
  add_bookings_to_calendar: true
)

# Test token expiration
connection.token_expired? # => false

# Manually sync a booking
booking = Scheduling::Booking.first
Scheduling::CalendarSyncJob.perform_now(booking.id, 'create')
```

### Debugging API Calls

Enable detailed logging:

```ruby
# In config/environments/development.rb
config.log_level = :debug

# Then check logs for API requests/responses
tail -f log/development.log | grep "Google\|Outlook\|Calendar"
```

---

## Security Best Practices

1. **Never commit OAuth credentials**: Use environment variables
2. **Use HTTPS in production**: Protect OAuth tokens in transit
3. **Encrypt tokens at rest**: Consider using Rails encrypted credentials
4. **Rotate secrets regularly**: Update client secrets periodically
5. **Limit scope**: Only request necessary calendar permissions
6. **State token validation**: Always verify state token in callbacks (already implemented)
7. **Token storage**: Store tokens securely in database (currently plaintext - consider encryption)

### Encrypting Tokens (Optional Enhancement)

```ruby
# In CalendarConnection model
encrypts :access_token, :refresh_token

# Requires Rails 7+ with Active Record Encryption configured
# See: https://edgeguides.rubyonrails.org/active_record_encryption.html
```

---

## Additional Resources

- [Google Calendar API Documentation](https://developers.google.com/calendar/api/guides/overview)
- [Microsoft Graph Calendar API](https://learn.microsoft.com/en-us/graph/api/resources/calendar)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [Google OAuth 2.0 Scopes](https://developers.google.com/identity/protocols/oauth2/scopes#calendar)

---

## Support

If you encounter issues:

1. Check the logs: `log/development.log` or `log/production.log`
2. Verify environment variables are set correctly
3. Ensure redirect URIs match exactly
4. Check that API permissions are granted
5. Test token refresh: `connection.refresh_access_token!`

For bugs or feature requests, please open an issue on the project repository.
