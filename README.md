# Scheduling - Rails 8 Multi-Tenant Scheduling Engine

A comprehensive, production-ready Rails 8 engine for multi-tenant appointment scheduling with organizational hierarchy, custom questions, payment integration, and multi-language/currency support.

## ✨ Features

✅ **Multi-Tenant Organization Structure** - Organizations → Locations → Teams → Members → Clients
✅ **Powerful Scheduling System** - Weekly availability, date overrides, buffer times
✅ **Smart Availability Checking** - Real-time conflict detection, external calendar integration
✅ **Custom Booking Questions** - Dynamic forms per event type
✅ **Payment Integration** - Stripe and Culqi support with multi-currency
✅ **Client Self-Service** - Cancel and reschedule with policy enforcement
✅ **Multi-Language** - ES, EN, PT, FR with browser detection
✅ **Calendar Sync** - Google Calendar and Outlook integration
✅ **Background Jobs** - Email notifications, calendar sync, payment processing

## 🚀 Quick Start

See `TEST_ENGINE.md` for a complete testing guide with the included dummy app.

## 📦 Installation in Host Application

### Step 1: Add to Gemfile

Add the gem to your Rails application's `Gemfile`:

```ruby
# If using from a git repository
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git'

# Or if installed locally for development
gem 'scheduling', path: '../scheduling'

# Or from RubyGems (when published)
# gem 'scheduling', '~> 1.0'
```

Then run:
```bash
bundle install
```

### Step 2: Ensure User Model Has Required Attributes

Your User model **must** have these attributes for delegation to work:

```ruby
# db/migrate/XXXXXX_add_scheduling_fields_to_users.rb
class AddSchedulingFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string unless column_exists?(:users, :first_name)
    add_column :users, :last_name, :string unless column_exists?(:users, :last_name)
    add_column :users, :email, :string unless column_exists?(:users, :email)
    add_column :users, :title, :string unless column_exists?(:users, :title)
    add_column :users, :bio, :text unless column_exists?(:users, :bio)
  end
end
```

Or if creating a new User model:

```ruby
rails generate model User first_name:string last_name:string email:string:uniq title:string bio:text
```

**Your User model should look like:**
```ruby
class User < ApplicationRecord
  has_many :scheduling_members, class_name: 'Scheduling::Member'

  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true
end
```

### Step 3: Install Migrations

Copy the engine's migrations to your host app:

```bash
rails scheduling:install:migrations
rails db:migrate
```

This will create 7 tables:
- `scheduling_organizations`, `scheduling_locations`, `scheduling_teams`
- `scheduling_members`, `scheduling_clients`
- `scheduling_event_types`, `scheduling_schedules`, `scheduling_availabilities`, `scheduling_date_overrides`
- `scheduling_bookings`, `scheduling_booking_questions`, `scheduling_booking_answers`, `scheduling_booking_changes`
- `scheduling_payments`
- `scheduling_calendar_connections`

### Step 4: Mount the Engine

Add to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Mount the scheduling engine
  mount Scheduling::Engine => "/scheduling"

  # Your other routes...
end
```

The engine will be available at:
- `http://localhost:3000/scheduling/:org_slug/:member_slug` - Member's booking page
- `http://localhost:3000/scheduling/:org_slug/:member_slug/:event_slug/book` - New booking

### Step 5: Create Initializer (**Required**)

Create `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  # ========================================
  # Organization Settings (REQUIRED)
  # ========================================
  config.organization_name = 'Clinica'           # Your organization name
  config.organization_slug = 'clinica'           # URL-friendly slug
  config.organization_timezone = 'America/Lima'  # Default timezone
  config.organization_currency = 'PEN'           # Default currency
  config.organization_locale = 'es'              # Default language

  # ========================================
  # Auto-Sync Settings (REQUIRED)
  # ========================================
  # Automatically create Scheduling::Member records when Users are created/updated
  config.auto_create_members = true
  config.sync_member_on_user_update = true

  # Default names for location/team when User doesn't have associations
  config.default_location_name = 'Sede Principal'
  config.default_team_name = 'Equipo por defecto'

  # ========================================
  # Optional Settings
  # ========================================
  # Locale settings
  config.default_locale = :es
  config.available_locales = [:es, :en, :pt, :fr]
  config.detect_locale_from_browser = true

  # Currency settings
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']

  # Booking policies
  config.default_cancellation_hours = 24
  config.default_rescheduling_hours = 24
  config.default_minimum_notice_hours = 2

  # Features
  config.send_confirmation_emails = true
  config.send_reminder_emails = false
  config.enable_sms_notifications = false

  # Payment providers (install gems separately)
  config.payment_providers = [:stripe, :culqi]
end
```

**How Auto-Sync Works:**

The engine automatically creates `Scheduling::Member` records when Users are created or updated:

- If `User` has a `location` association → uses `user.location.name`
- If not → creates default location: "Sede Principal"
- If `User` has a `team` association → uses `user.team.name`
- If not → creates default team: "Equipo por defecto"

**No manual setup script needed!** The engine handles everything automatically via callbacks.

### Step 6: Add Optional Payment Gems

**For Stripe payments:**
```ruby
# Gemfile
gem 'stripe', '~> 10.0'
```

Set environment variables:
```bash
# .env or config/credentials.yml
STRIPE_API_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

**For Culqi payments (Peru):**
```ruby
# Gemfile
gem 'culqi-ruby'  # or use HTTP client directly
```

Set environment variables:
```bash
CULQI_PUBLIC_KEY=pk_test_...
CULQI_SECRET_KEY=sk_test_...
```

### Step 7: Create Your First User - Members Auto-Created!

**That's it!** When you create a User, the engine automatically creates the corresponding `Scheduling::Member`:

```ruby
# Just create a user as normal
user = User.create!(
  first_name: "Dr. Carlos",
  last_name: "Mendoza",
  email: "carlos@clinica.com",
  title: "Médico General",
  bio: "Especialista en medicina general"
)

# Member is automatically created via callback!
member = Scheduling::Member.find_by(user: user)
# => #<Scheduling::Member booking_slug: "dr-carlos-mendoza", ...>
```

The engine automatically:
- ✅ Creates organization (if doesn't exist)
- ✅ Creates location (from user.location or default)
- ✅ Creates team (from user.team or default)
- ✅ Creates member record
- ✅ Syncs on user updates

**Optional: Manual Setup for Advanced Cases**

If you need to create organization/members manually (for testing, seeding, etc.):

```ruby
# In rails console or db/seeds.rb

# Create a user
user = User.create!(
  first_name: "Dr. Jane",
  last_name: "Smith",
  email: "jane@clinic.com",
  title: "General Practitioner",
  bio: "20 years of experience in family medicine"
)

# Create organization
org = Scheduling::Organization.create!(
  name: "My Medical Clinic",
  slug: "my-clinic",
  timezone: "America/New_York",
  default_currency: "USD",
  default_locale: "en"
)

# Create location
location = org.locations.create!(
  name: "Main Office",
  slug: "main",
  address: "123 Medical Dr",
  city: "New York",
  state: "NY",
  country: "USA",
  postal_code: "10001",
  timezone: "America/New_York"
)

# Create team
team = location.teams.create!(
  name: "General Practice",
  slug: "general-practice"
)

# Create member
member = team.members.create!(
  user: user,
  role: "admin",
  active: true,
  accepts_bookings: true
)

# Create schedule (Monday-Friday, 9 AM - 5 PM)
schedule = member.schedules.create!(
  name: "Office Hours",
  timezone: "America/New_York",
  is_default: true
)

(1..5).each do |day|  # Monday = 1, Friday = 5
  schedule.availabilities.create!(
    day_of_week: day,
    start_time: "09:00",
    end_time: "17:00"
  )
end

# Create event type
event_type = member.event_types.create!(
  title: "30-Minute Consultation",
  slug: "consultation",
  description: "General medical consultation",
  duration_minutes: 30,
  buffer_before_minutes: 5,
  buffer_after_minutes: 10,
  minimum_notice_hours: 24,
  maximum_days_in_future: 90,
  price_cents: 15000,  # $150.00
  price_currency: "USD",
  active: true,
  requires_payment: true,
  payment_required_to_book: false,  # Pay after booking
  allow_cancellation: true,
  cancellation_policy_hours: 24,
  allow_rescheduling: true,
  rescheduling_policy_hours: 24
)

puts "✅ Setup complete!"
puts "Visit: http://localhost:3000/scheduling/my-clinic/#{member.booking_slug}"
```

### Step 8: Create Schedules and Event Types

Members are created automatically, but you still need to set up their availability:

```ruby
member = Scheduling::Member.first

# Create schedule (Monday-Friday, 9am-5pm)
schedule = member.schedules.create!(
  name: "Office Hours",
  timezone: "America/Lima",
  is_default: true
)

(1..5).each do |day|
  schedule.availabilities.create!(
    day_of_week: day,
    start_time: "09:00",
    end_time: "17:00"
  )
end

# Create event type (appointment type)
event_type = member.event_types.create!(
  title: "Medical Consultation",
  slug: "consultation",
  duration_minutes: 30,
  minimum_notice_hours: 2,
  maximum_days_in_future: 60,
  price_cents: 10000,
  price_currency: "PEN",
  active: true
)
```

### Step 9: Test the Integration

Start your Rails server:
```bash
rails server
```

Visit the booking page:
```
http://localhost:3000/scheduling/clinica/dr-carlos-mendoza
```

Or test availability in console:
```ruby
member = Scheduling::Member.first
event_type = member.event_types.first
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))
puts "Found #{slots.count} available slots"
```

## 🎯 Quick Start (For Engine Development)

If you want to develop or test the engine itself:

```bash
bundle install
rails scheduling:install:migrations
rails db:migrate
```

### Basic Usage

```ruby
# Create organization
org = Scheduling::Organization.create!(name: "My Clinic", slug: "my-clinic")

# Create location and team
location = org.locations.create!(name: "Downtown", slug: "downtown")
team = location.teams.create!(name: "Cardiology", slug: "cardiology")

# Create member (requires User model with first_name, last_name, email, title, bio)
member = team.members.create!(user: user, role: "admin")

# Set up schedule
schedule = member.schedules.create!(name: "Hours", timezone: "America/Lima", is_default: true)
schedule.availabilities.create!(day_of_week: 1, start_time: "09:00", end_time: "17:00")

# Create event type
event_type = member.event_types.create!(
  title: "Consultation",
  slug: "consultation",
  duration_minutes: 30,
  price_cents: 15000,
  price_currency: "PEN"
)

# Check availability
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))
```

### Public Booking URLs

Mount the engine in `config/routes.rb`:

```ruby
mount Scheduling::Engine => "/scheduling"
```

Access at:
- `http://localhost:3000/scheduling/my-clinic/member-slug` - Member's booking page
- `http://localhost:3000/scheduling/my-clinic/member-slug/event-slug/book` - Book appointment

## 📚 Documentation

- **`README.md`** - This file - installation and usage guide
- **`setup_host_scheduling.rb`** - Ready-to-use setup script for quick start
- **`TEST_ENGINE.md`** - Complete testing guide with examples
- **`DATA_OWNERSHIP.md`** - Architecture and DRY principles
- **`REFACTORING_SUMMARY.md`** - How we avoid data duplication
- **`CLAUDE.md`** - Guide for AI assistants working with this codebase
- **`planning.md`** - Full technical specification

## 🛠️ What's Included

**14 Models** with full business logic
**5 Services** for availability, payments, calendars
**5 Background Jobs** for async processing
**1 Controller** for public booking interface
**7 Migrations** for complete database schema

## 🏗️ Architecture Highlights

### Data Ownership (DRY Principles)

User data lives in the **host app's User model**:
- first_name, last_name, email, title, bio

Scheduling data lives in the **engine's Member model**:
- role, booking_slug, active, accepts_bookings

The Member model **delegates** to User, avoiding duplication while maintaining flexibility.

### Services

- `AvailabilityChecker` - Smart slot generation with conflict detection
- `StripePaymentService` / `CulqiPaymentService` - Payment processing
- `GoogleCalendarService` / `OutlookCalendarService` - Calendar sync

## 💳 Payment Setup

**Stripe:**
```ruby
gem 'stripe', '~> 10.0'
# Set ENV['STRIPE_API_KEY'] and ENV['STRIPE_PUBLISHABLE_KEY']
```

**Culqi (Peru):**
```bash
gem install culqi-ruby
# Set ENV['CULQI_PUBLIC_KEY'] and ENV['CULQI_SECRET_KEY']
```

## 🎨 Customization

Configure in `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  config.default_locale = :es
  config.available_locales = [:es, :en, :pt, :fr]
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']
  config.default_cancellation_hours = 24
  config.send_confirmation_emails = true
end
```

## 🧪 Testing

The engine includes a dummy app at `test/dummy/`:

```bash
rails console
# Then try the examples in TEST_ENGINE.md
```

## 📋 Requirements

**Host App Must Provide:**
- User model with: `first_name`, `last_name`, `email`, `title`, `bio`
- PostgreSQL database
- Rails 8.0+

**Optional Dependencies:**
- `stripe` gem for Stripe payments
- `culqi-ruby` gem for Culqi payments (Peru)
- `google-api-client` for Google Calendar
- OAuth2 credentials for calendar integrations

## 🤝 Contributing

1. Fork it
2. Create feature branch (`git checkout -b feature/my-feature`)
3. Commit changes (`git commit -am 'Add feature'`)
4. Push branch (`git push origin feature/my-feature`)
5. Create Pull Request

## 📄 License

MIT License - see [MIT-LICENSE](MIT-LICENSE) file.

## 👨‍💻 Author

Augusto Samame (augustosamame@gmail.com)
