# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **Rails 8+ mountable engine** providing multi-tenant appointment scheduling with organizational hierarchy (Organization → Location → Team → Member → Client), payment integration, calendar sync, and self-service booking management.

## Development Environment

**RVM Setup**: This project uses RVM with a specific gemset:
```bash
rvm 3.3.4@scheduling
```

**Critical**: Always prefix Rails commands with the RVM environment:
```bash
rvm 3.3.4@scheduling do bin/rails console
rvm 3.3.4@scheduling do bin/rails generate migration ...
rvm 3.3.4@scheduling do bin/rails db:migrate
```

## Common Commands

### Automatic Member Sync (Important!)

**The engine automatically creates `Scheduling::Member` records** when Users are created or updated via callbacks:

- User created/updated → `Scheduling::MemberSyncService` runs automatically
- Organization/Location/Team created if they don't exist
- Member record created and linked to User
- Uses `user.location` and `user.team` if available
- Falls back to configured defaults if associations don't exist

**Key Files:**
- `app/services/scheduling/member_sync_service.rb` - Sync logic
- `lib/scheduling/user_extensions.rb` - Callback concern
- `lib/scheduling/engine.rb` - Auto-includes concern into User model

**Configuration Required:**
```ruby
# config/initializers/scheduling.rb
Scheduling.configure do |config|
  config.organization_name = 'Clinica'
  config.organization_slug = 'clinica'
  config.auto_create_members = true  # Enable auto-sync
  config.sync_member_on_user_update = true
end
```

### Testing with Dummy App

The engine includes a full dummy Rails app at `test/dummy/` for testing:

```bash
# Console (with sample data)
rvm 3.3.4@scheduling do bin/rails console

# Database operations
rvm 3.3.4@scheduling do bin/rails db:create
rvm 3.3.4@scheduling do bin/rails db:migrate
rvm 3.3.4@scheduling do bin/rails db:seed

# Install migrations to host app
rails scheduling:install:migrations

# Run tests (when available)
bundle exec rspec
```

### Quick Testing in Console

The `.irbrc` file provides helper methods. In console:

```ruby
# Check availability
check_slots(7)  # Next 7 days

# Get sample data
sample_member
sample_event_type
sample_organization

# Test booking flow
member = Scheduling::Member.first
event_type = member.event_types.first
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))
```

## Architecture Principles

### Data Ownership (DRY Pattern)

**Critical Design Decision**: The engine uses delegation to avoid duplicating user data.

**Host App User Model** owns identity data:
- `first_name`, `last_name`, `email`
- `title` (professional title)
- `bio` (professional biography)

**Engine Member Model** owns scheduling data:
- `role` (admin/manager/member - team-specific)
- `booking_slug` (URL-friendly identifier)
- `active`, `accepts_bookings` (availability flags)
- `settings` (JSONB scheduling preferences)

**Implementation**:
```ruby
class Scheduling::Member < ApplicationRecord
  belongs_to :user
  delegate :first_name, :last_name, :email, :title, :bio, to: :user

  def full_name
    "#{first_name} #{last_name}"
  end
end
```

**When Adding Features**:
- User identity/professional info → delegate to `user`
- Scheduling-specific data → store in `member`
- See `DATA_OWNERSHIP.md` for detailed guidelines

### Multi-Tenancy

All scheduling data is scoped to an `Organization`:

```ruby
org = Scheduling::Organization.find_by(slug: 'clinica-lima')
org.locations.first.teams.first.members
```

**URL Pattern**: `/:organization_slug/:member_booking_slug/:event_slug/book`

### Optional Dependencies

Payment and calendar features use feature detection:

```ruby
# In services
raise NotImplementedError, "Stripe not installed" unless defined?(Stripe)
```

**Optional gems** (commented in gemspec):
- `stripe` - Stripe payments
- External Culqi gem - Peruvian payments

## Core Services

### AvailabilityChecker - The Scheduling Brain

Location: `app/services/scheduling/availability_checker.rb`

**Purpose**: Calculates available time slots considering:
- Weekly recurring schedules (`Schedule` + `Availability`)
- Date overrides (holidays, special hours)
- Buffer times (before/after appointments)
- Minimum notice periods
- Maximum booking windows
- Booking conflicts (internal)
- External calendar conflicts (Google/Outlook)

**Usage**:
```ruby
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7), 'America/Lima')
# Returns: [{ start_time: Time, end_time: Time, available: true }, ...]

# Check specific time
checker.available_at?(time, duration_minutes)
```

**Key Logic**:
1. Checks `DateOverride` first (takes precedence over weekly schedule)
2. Falls back to `Availability` (day of week schedule)
3. Applies buffers and minimum notice
4. Filters out conflicts
5. Checks external calendars if connected

### Payment Services

Location: `app/services/scheduling/*_payment_service.rb`

**StripePaymentService**:
```ruby
service = StripePaymentService.new(booking, payment_method_id)
result = service.process  # { success: true, payment: Payment }
StripePaymentService.refund(payment)
```

**CulqiPaymentService**: Similar API for Peru-based payments

### Calendar Services

**GoogleCalendarService** and **OutlookCalendarService**:
```ruby
service = GoogleCalendarService.new(calendar_connection)
service.add_booking(booking)
service.update_booking(booking)
service.delete_booking(external_event_id)
service.has_conflicts?(start_time, end_time)
```

## Core Models

### Booking - Complete Lifecycle

Location: `app/models/scheduling/booking.rb`

**Status Flow**: `confirmed` → `cancelled` / `rescheduled` / `completed` / `no_show`

**Key Methods**:
```ruby
booking.can_cancel?      # Checks policy hours
booking.can_reschedule?  # Checks policy hours

booking.cancel!(reason: "...", initiated_by: 'client')
# - Creates BookingChange audit record
# - Processes refund if payment exists
# - Sends email notification
# - Removes from external calendar

booking.reschedule_to!(new_start_time, reason: "...", initiated_by: 'client')
# - Creates new Booking with new time
# - Transfers payment and answers
# - Marks old booking as 'rescheduled'
# - Updates external calendar
```

**Token-Based Self-Service**:
- `uid` - Public identifier for confirmation page
- `cancellation_token` - Secure token for cancel URL
- `reschedule_token` - Secure token for reschedule URL

### EventType - Appointment Configuration

**Key Attributes**:
- `duration_minutes` - Base appointment length
- `buffer_before_minutes`, `buffer_after_minutes` - Padding
- `minimum_notice_hours` - How far in advance required
- `maximum_days_in_future` - Booking window limit
- `price_cents`, `price_currency` - MoneyRails integration
- `cancellation_policy_hours`, `rescheduling_policy_hours`

### Member - Delegation Pattern

**Always use delegation** for user attributes:
```ruby
member.first_name  # delegates to user.first_name
member.email       # delegates to user.email
member.title       # delegates to user.title
```

**Scheduling-specific attributes**:
```ruby
member.booking_slug        # URL identifier (stable, never changes)
member.accepts_bookings    # Availability toggle
member.default_schedule    # Primary weekly schedule
```

## Database Migrations

**7 Core Migrations** (sequential):
1. `create_scheduling_organizations` - Org structure + members + clients
2. `create_scheduling_event_types` - Appointment types
3. `create_scheduling_schedules` - Availability system
4. `create_scheduling_bookings` - Bookings + changes
5. `create_scheduling_booking_questions` - Custom forms
6. `create_scheduling_payments` - Payment records
7. `create_scheduling_calendar_connections` - External calendars

**Host App Requirements**:
- User model with: `first_name`, `last_name`, `email`, `title`, `bio`
- PostgreSQL database

## Background Jobs

All use Solid Queue:

- `CalendarSyncJob` - Sync to Google/Outlook
- `BookingConfirmationJob` - Send confirmation emails
- `BookingCancellationJob` - Send cancellation emails
- `BookingRescheduleJob` - Send reschedule notifications
- `PaymentRefundJob` - Process refunds

**Pattern**:
```ruby
after_create :send_confirmation_email

def send_confirmation_email
  BookingConfirmationJob.perform_later(id)
end
```

## Public Booking Controller

Location: `app/controllers/scheduling/public_bookings_controller.rb`

**Complete booking flow** for customers (no authentication required):

**Routes**:
```
GET  /:org/:member              → index (list event types)
GET  /:org/:member/:event/book  → new (booking form)
POST /:org/:member/:event/book  → create (process booking)
GET  /bookings/:uid             → show (confirmation)
GET  /bookings/:token/cancel    → cancel (form)
POST /bookings/:token/cancel    → process_cancellation
GET  /bookings/:token/reschedule → reschedule (form)
POST /bookings/:token/reschedule → process_reschedule
GET  /:org/:member/:event/availability → AJAX slots
```

**Key Features**:
- Auto-detects locale from browser (`Accept-Language`)
- Validates policy hours before cancel/reschedule
- Integrates with payment services
- Handles custom booking questions
- Multi-timezone support

## Configuration

Location: `config/initializers/scheduling.rb`

**All Available Configuration Options:**

```ruby
Scheduling.configure do |config|
  # ========================================
  # Organization Settings (REQUIRED for auto-sync)
  # ========================================
  config.organization_name = 'Clinica'
  config.organization_slug = 'clinica'
  config.organization_timezone = 'America/Lima'
  config.organization_currency = 'PEN'
  config.organization_locale = 'es'

  # Default location/team names (fallbacks when user has no associations)
  config.default_location_name = 'Sede Principal'
  config.default_team_name = 'Equipo por defecto'

  # ========================================
  # Auto-Sync Settings
  # ========================================
  config.auto_create_members = true             # Auto-create Member from User
  config.sync_member_on_user_update = true      # Sync on User updates

  # ========================================
  # Locale settings
  # ========================================
  config.default_locale = :es
  config.available_locales = [:es, :en, :pt, :fr]
  config.detect_locale_from_browser = true

  # ========================================
  # Currency settings
  # ========================================
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']

  # ========================================
  # Booking policies
  # ========================================
  config.default_cancellation_hours = 24
  config.default_rescheduling_hours = 24
  config.default_minimum_notice_hours = 2

  # ========================================
  # Notifications
  # ========================================
  config.send_confirmation_emails = true
  config.send_reminder_emails = true
  config.reminder_hours_before = 24
  config.enable_sms_notifications = false

  # ========================================
  # Payment and calendar integrations
  # ========================================
  config.payment_providers = [:stripe, :culqi]
  config.enable_google_calendar = true
  config.enable_outlook_calendar = true

  # ========================================
  # Multi-tenancy
  # ========================================
  config.enable_multi_tenancy = true
end
```

## Timezone Handling

**Important**: Timezone validation was intentionally removed to allow flexibility.

**Best Practices**:
- Always store times in UTC in database
- Convert to user's timezone for display
- Use `ActiveSupport::TimeZone` for conversions
- Each organization/location/schedule can have different timezone

## When Making Schema Changes

1. **Check delegation first** - Does this belong in User or Member?
2. **Create migration** with proper namespace: `rvm 3.3.4@scheduling do bin/rails generate migration ...`
3. **Update model** - Add validations, scopes, methods
4. **Update dummy app** - Regenerate seeds if needed
5. **Update docs** - README, DATA_OWNERSHIP.md if architecture changes

## Common Patterns

### Creating a Booking Programmatically

```ruby
booking = event_type.bookings.create!(
  member: member,
  client: client,
  start_time: time,
  timezone: 'America/Lima',
  locale: 'es',
  notes: 'Patient notes'
)

# Add answers to custom questions
booking.booking_answers.create!(
  booking_question: question,
  answer: 'Response text'
)
```

### Adding Date Override (Holiday)

```ruby
member.date_overrides.create!(
  date: Date.new(2024, 12, 25),
  reason: 'Christmas',
  unavailable: true
)
```

### Adding Special Hours

```ruby
member.date_overrides.create!(
  date: Date.new(2024, 12, 24),
  reason: 'Christmas Eve - Half Day',
  unavailable: false,
  start_time: '09:00',
  end_time: '13:00'
)
```

## Documentation Files

- `README.md` - Installation and quick start
- `IMPLEMENTATION_COMPLETE.md` - Full feature list and file structure
- `DATA_OWNERSHIP.md` - Architecture decisions on data delegation
- `REFACTORING_SUMMARY.md` - History of DRY refactoring
- `TEST_ENGINE.md` - Testing guide with examples
- `planning.md` - Original specification (reference only)

## Known Limitations

1. **Views not included** - Controllers are ready, but HTML/ERB templates must be created
2. **Email templates not implemented** - Jobs exist but mailer is placeholder
3. **Payment gems optional** - Stripe/Culqi require separate installation
4. **OAuth setup required** - Calendar sync needs Google/Microsoft credentials
5. **MoneyRails conditional** - Currency features wrapped in `if defined?(MoneyRails)`
