# Implementing the Scheduling Engine in Your Rails Project

This guide shows you how to integrate the Scheduling engine into your existing Rails application.

## Prerequisites

- Rails 8.0+ application
- PostgreSQL database
- User model (or ability to create one)
- Ruby 3.3.4+ (recommended)

---

## 📦 Step 1: Add the Gem

Add to your `Gemfile`:

```ruby
# From git (recommended for latest features)
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git'

# Or from a specific version tag
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git', tag: 'v0.2.0'

# Or from local path (for development)
gem 'scheduling', path: '../scheduling'

# Or from RubyGems (when published)
# gem 'scheduling', '~> 0.2.0'
```

Then install:

```bash
bundle install
```

---

## 👤 Step 2: Ensure User Model Has Required Attributes

The engine requires your `User` model to have these attributes:

### Required Fields:
- `first_name` (string)
- `last_name` (string)
- `email` (string)
- `title` (string) - Professional title
- `bio` (text) - Professional biography

### Add Missing Fields

If you don't have these fields, create a migration:

```bash
rails generate migration AddSchedulingFieldsToUsers first_name:string last_name:string title:string bio:text
```

Or if you already have some fields:

```ruby
# db/migrate/XXXXXX_add_scheduling_fields_to_users.rb
class AddSchedulingFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string unless column_exists?(:users, :first_name)
    add_column :users, :last_name, :string unless column_exists?(:users, :last_name)
    add_column :users, :title, :string unless column_exists?(:users, :title)
    add_column :users, :bio, :text unless column_exists?(:users, :bio)

    # Email usually exists from Devise/authentication, but add if needed:
    # add_column :users, :email, :string unless column_exists?(:users, :email)
  end
end
```

Run the migration:

```bash
rails db:migrate
```

### Update User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :scheduling_members, class_name: 'Scheduling::Member', dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
```

---

## 🗄️ Step 3: Install Engine Migrations

Copy the engine's migrations to your app:

```bash
rails scheduling:install:migrations
```

This creates 7 migration files in `db/migrate/`:
- `create_scheduling_organizations`
- `create_scheduling_event_types`
- `create_scheduling_schedules`
- `create_scheduling_bookings`
- `create_scheduling_booking_questions`
- `create_scheduling_payments`
- `create_scheduling_calendar_connections`

Run the migrations:

```bash
rails db:migrate
```

---

## 🔧 Step 4: Create Initializer (**Required**)

Create `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  # ========================================
  # Organization Settings (REQUIRED)
  # ========================================
  config.organization_name = 'Your Company Name'
  config.organization_slug = 'your-company'  # URL-friendly, no spaces
  config.organization_timezone = 'America/New_York'  # Your timezone
  config.organization_currency = 'USD'
  config.organization_locale = 'en'

  # ========================================
  # Auto-Sync Settings (REQUIRED)
  # ========================================
  # Automatically create Scheduling::Member when Users are created/updated
  config.auto_create_members = true
  config.sync_member_on_user_update = true

  # Automatically create default schedule and event type for new members
  config.auto_create_default_schedule = true     # Creates Mon-Fri 9am-5pm schedule
  config.auto_create_default_event_type = true   # Creates "General Appointment" event type

  # Fallback names when User doesn't have location/team associations
  config.default_location_name = 'Main Office'
  config.default_team_name = 'Default Team'

  # ========================================
  # Optional Settings
  # ========================================
  # Locale settings
  config.default_locale = :en
  config.available_locales = [:en, :es, :pt, :fr]
  config.detect_locale_from_browser = true

  # Currency settings
  config.default_currency = 'USD'
  config.available_currencies = ['USD', 'EUR', 'GBP', 'PEN']

  # Booking policies (defaults)
  config.default_cancellation_hours = 24
  config.default_rescheduling_hours = 24
  config.default_minimum_notice_hours = 2

  # Notifications
  config.send_confirmation_emails = true
  config.send_reminder_emails = false
  config.enable_sms_notifications = false

  # Payment providers (optional - install gems separately)
  config.payment_providers = [:stripe]  # or [:stripe, :culqi]

  # Calendar integrations (optional - need OAuth setup)
  config.enable_google_calendar = false
  config.enable_outlook_calendar = false
end
```

**Important Configuration Notes:**

- `organization_name` and `organization_slug` are **required** for auto-sync to work
- `organization_slug` must be URL-friendly (lowercase, no spaces, use hyphens)
- `organization_timezone` should match your business timezone
- Set `auto_create_members = true` to enable automatic Member creation
- Adjust default policies based on your business requirements

---

## 🛣️ Step 5: Mount the Engine Routes

Add to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Your main app routes
  root 'home#index'
  resources :users
  get '/dashboard', to: 'dashboard#show'

  # Mount scheduling engine at a clear subpath
  mount Scheduling::Engine => "/book"  # Recommended!
end
```

### Mounting Options

⚠️ **Important:** The engine has greedy routes like `/:organization_slug/:member_slug` that will conflict with your main app routes if mounted at root!

**Option 1: Subpath (Recommended for most apps)**
```ruby
mount Scheduling::Engine => "/book"
# or "/appointments", "/schedule", "/cal", etc.
```
- ✅ URLs: `/book/test-clinic/dr-maria-rodriguez`
- ✅ No route conflicts with main app
- ✅ Clear separation of concerns
- ✅ Recommended for production apps

**Option 2: Subdomain (Best for scalability)**
```ruby
# Requires subdomain DNS setup
constraints subdomain: 'book' do
  mount Scheduling::Engine => "/"
end
```
- ✅ URLs: `https://book.example.com/test-clinic/dr-maria-rodriguez`
- ✅ Cleanest URLs
- ✅ Complete route isolation
- ✅ Can scale to per-organization subdomains
- ⚠️  Requires DNS/SSL configuration

**Option 3: Root mounting (Only for dedicated booking apps)**
```ruby
mount Scheduling::Engine => "/"
```
- ⚠️  **Only use if your app has NO other routes**
- ⚠️  Will conflict with routes like `/dashboard`, `/users/:id`, etc.
- ✅ Good for dummy/test apps or single-purpose booking sites

### Available Routes

When mounted at `/book`:
- Member's event types: `/book/:org_slug/:member_slug`
- Booking form: `/book/:org_slug/:member_slug/:event_slug/book`
- Confirmation: `/book/bookings/:uid`
- Cancel: `/book/bookings/:token/cancel`
- Reschedule: `/book/bookings/:token/reschedule`

---

## ✅ Step 6: Verify Installation

Restart your Rails server and test in console:

```bash
rails console
```

```ruby
# Check configuration
Scheduling.configuration.organization_name
# => "Your Company Name"

Scheduling.configuration.auto_create_members
# => true

# Check if UserExtensions is included
User.included_modules.include?(Scheduling::UserExtensions)
# => true (if config.auto_create_members is true)
```

---

## 🎯 Step 7: Create Your First User - Watch Auto-Sync!

Create a user (or use existing users):

```ruby
user = User.create!(
  first_name: "Dr. Sarah",
  last_name: "Johnson",
  email: "sarah@example.com",
  title: "General Practitioner",
  bio: "Board-certified family medicine physician"
)

# Member should be auto-created!
member = Scheduling::Member.find_by(user: user)

puts "Member created: #{member.present? ? 'YES! ✅' : 'NO ❌'}"
puts "Booking slug: #{member.booking_slug}" if member
# => "dr-sarah-johnson"

puts "Organization: #{Scheduling::Organization.first.name}"
# => "Your Company Name"
```

**What Just Happened:**

1. ✅ User created
2. ✅ Organization auto-created (from config)
3. ✅ Location auto-created (default: "Main Office")
4. ✅ Team auto-created (default: "Default Team")
5. ✅ Member auto-created and linked to User
6. ✅ `booking_slug` generated from user's name
7. ✅ **Default schedule auto-created** (Monday-Friday, 9 AM - 5 PM)
8. ✅ **Default event type auto-created** ("General Appointment", 30 min, free)

**The member is now ready to accept bookings immediately!** No need to manually create schedules or event types.

---

## 📅 Step 8: Customize Schedules (Optional)

**If you enabled `auto_create_default_schedule = true`**, members already have a default Monday-Friday 9am-5pm schedule. You can customize it or add additional schedules:

```ruby
member = Scheduling::Member.first

# Create a schedule (Monday-Friday, 9 AM - 5 PM)
schedule = member.schedules.create!(
  name: "Office Hours",
  timezone: "America/New_York",
  is_default: true
)

# Add availability for each weekday
(1..5).each do |day|  # 1 = Monday, 5 = Friday
  schedule.availabilities.create!(
    day_of_week: day,
    start_time: "09:00",
    end_time: "17:00"
  )
end

puts "Schedule created with #{schedule.availabilities.count} days"
```

---

## 🎫 Step 9: Customize Event Types (Optional)

**If you enabled `auto_create_default_event_type = true`**, members already have a "General Appointment" event type. You can customize it or add more event types:

```ruby
member = Scheduling::Member.first

event_type = member.event_types.create!(
  title: "Initial Consultation",
  slug: "initial-consultation",
  description: "First-time patient consultation",
  location_type: "in_person",  # or "video", "phone"
  location_details: "Main Office, Room 101",
  duration_minutes: 30,
  buffer_before_minutes: 5,
  buffer_after_minutes: 10,
  minimum_notice_hours: 24,  # Book at least 24hrs in advance
  maximum_days_in_future: 90,  # Can book up to 90 days out
  color: "#3b82f6",
  active: true,
  requires_payment: true,
  price_cents: 15000,  # $150.00
  price_currency: "USD",
  payment_required_to_book: false,  # Can pay after booking
  allow_rescheduling: true,
  rescheduling_policy_hours: 24,
  allow_cancellation: true,
  cancellation_policy_hours: 24
)

# Add custom booking questions
event_type.booking_questions.create!(
  label: "What is the reason for your visit?",
  question_type: "textarea",
  required: true,
  position: 1,
  placeholder: "Please describe your symptoms or concerns",
  help_text: "This helps us prepare for your appointment"
)

event_type.booking_questions.create!(
  label: "Do you have any allergies?",
  question_type: "text",
  required: false,
  position: 2,
  placeholder: "List any known allergies"
)

puts "Event type created: #{event_type.title}"
```

---

## 🧪 Step 10: Test Availability

```ruby
member = Scheduling::Member.first
event_type = member.event_types.first

# Check availability
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))

puts "Found #{slots.count} available slots in next 7 days"

# View some slots
slots.first(5).each do |slot|
  puts slot[:start_time].strftime('%A, %B %d at %I:%M %p')
end
```

---

## 🌐 Step 11: Access the Booking Page

Visit in your browser:

```
http://localhost:3000/scheduling/your-company/dr-sarah-johnson
```

You should see the member's booking page with available event types.

To book an appointment:

```
http://localhost:3000/scheduling/your-company/dr-sarah-johnson/initial-consultation/book
```

---

## 🔄 Optional: User Associations (Advanced)

If your User model has `location` or `team` associations, the engine will use them automatically:

```ruby
# Add to User model
class User < ApplicationRecord
  belongs_to :location, optional: true
  belongs_to :team, optional: true
end

# When creating users
location = Location.create!(name: "Downtown Office")
team = Team.create!(name: "Cardiology Department")

user = User.create!(
  first_name: "Dr. John",
  last_name: "Smith",
  email: "john@example.com",
  location: location,
  team: team
)

# Engine will use user.location.name and user.team.name
member = Scheduling::Member.find_by(user: user)
puts member.team.name
# => "Cardiology Department" (from user.team.name)
```

If User doesn't have these associations, the engine falls back to configured defaults.

---

## 💳 Optional: Payment Integration

### Stripe

1. Add to Gemfile:
   ```ruby
   gem 'stripe', '~> 10.0'
   ```

2. Set environment variables:
   ```bash
   # .env or config/credentials.yml
   STRIPE_API_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

3. Enable in initializer:
   ```ruby
   config.payment_providers = [:stripe]
   ```

### Culqi (Peru)

1. Install gem separately (not in RubyGems yet)
2. Set environment variables:
   ```bash
   CULQI_PUBLIC_KEY=pk_test_...
   CULQI_SECRET_KEY=sk_test_...
   ```

3. Enable in initializer:
   ```ruby
   config.payment_providers = [:culqi]
   ```

---

## 📧 Optional: Email Notifications

The engine includes background jobs for notifications, but you need to implement the mailer:

```ruby
# app/mailers/scheduling/booking_mailer.rb
module Scheduling
  class BookingMailer < ApplicationMailer
    def confirmation_email(booking_id)
      @booking = Booking.find(booking_id)
      mail(
        to: @booking.client.email,
        subject: "Booking Confirmation - #{@booking.event_type.title}"
      )
    end

    def cancellation_email(booking_id)
      @booking = Booking.find(booking_id)
      mail(
        to: @booking.client.email,
        subject: "Booking Cancelled"
      )
    end

    def reschedule_email(booking_id)
      @booking = Booking.find(booking_id)
      mail(
        to: @booking.client.email,
        subject: "Booking Rescheduled"
      )
    end
  end
end
```

---

## 🐛 Troubleshooting

### Members Not Auto-Creating

**Check 1:** Verify configuration

```ruby
Scheduling.configuration.auto_create_members
# => Should be true
```

**Check 2:** Verify UserExtensions is loaded

```ruby
User.included_modules.include?(Scheduling::UserExtensions)
# => Should be true
```

**Check 3:** Check logs

```bash
tail -f log/development.log
```

Look for errors like "Failed to sync scheduling member"

**Check 4:** User has required fields

```ruby
user = User.first
user.first_name.present?  # => true
user.last_name.present?   # => true
```

### No Available Slots

**Check 1:** Member has a schedule

```ruby
member.schedules.any?
# => Should be true
```

**Check 2:** Schedule has availabilities

```ruby
member.default_schedule.availabilities.count
# => Should be > 0
```

**Check 3:** Check minimum notice

```ruby
event_type.minimum_notice_hours
# => If this is 24, you need to check slots > 24 hours from now
```

### Route Not Found

Make sure you mounted the engine:

```ruby
# config/routes.rb
mount Scheduling::Engine => "/"  # or "/scheduling" if using a subpath
```

Restart the server after adding routes.

---

## 📊 Seed Data (Optional)

Create `db/seeds.rb` (or add to existing):

```ruby
# Create users - Members will auto-create!
users_data = [
  { first_name: "Dr. Sarah", last_name: "Johnson", email: "sarah@clinic.com", title: "General Practitioner" },
  { first_name: "Dr. Michael", last_name: "Chen", email: "michael@clinic.com", title: "Cardiologist" },
  { first_name: "Dr. Emily", last_name: "Rodriguez", email: "emily@clinic.com", title: "Pediatrician" }
]

users_data.each do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.first_name = data[:first_name]
    u.last_name = data[:last_name]
    u.title = data[:title]
    u.bio = "Experienced #{data[:title].downcase}"
  end

  member = Scheduling::Member.find_by(user: user)

  # Create schedule
  schedule = member.schedules.find_or_create_by!(name: "Office Hours", is_default: true) do |s|
    s.timezone = "America/New_York"
  end

  if schedule.availabilities.empty?
    (1..5).each do |day|
      schedule.availabilities.create!(
        day_of_week: day,
        start_time: "09:00",
        end_time: "17:00"
      )
    end
  end

  # Create event types
  member.event_types.find_or_create_by!(slug: "consultation") do |et|
    et.title = "30-Minute Consultation"
    et.duration_minutes = 30
    et.minimum_notice_hours = 24
    et.maximum_days_in_future = 90
    et.price_cents = 15000
    et.price_currency = "USD"
    et.active = true
  end
end

puts "✅ Seed data created!"
puts "   Users: #{User.count}"
puts "   Members: #{Scheduling::Member.count}"
puts "   Organizations: #{Scheduling::Organization.count}"
```

Run seeds:

```bash
rails db:seed
```

---

## 🚀 Next Steps

1. **Customize views** - The engine provides controllers but you'll want to create your own views
2. **Add authentication** - Protect member/admin areas
3. **Implement mailers** - For booking confirmations
4. **Set up payments** - Configure Stripe/Culqi
5. **Calendar sync** - Set up OAuth for Google/Outlook
6. **Customize policies** - Adjust cancellation/rescheduling rules per event type

---

## 📚 Additional Resources

- **TEST_ENGINE.md** - How to test the engine in isolation
- **CLAUDE.md** - Architecture and development guide
- **DATA_OWNERSHIP.md** - Understanding the delegation pattern
- **README.md** - General overview and features

---

## ✅ Checklist

Before going to production, verify:

- [ ] User model has all required fields (first_name, last_name, email, title, bio)
- [ ] Initializer created with correct organization settings
- [ ] Auto-sync enabled and working (test by creating a user)
- [ ] Routes mounted
- [ ] Schedules created for all members who accept bookings
- [ ] Event types created with correct pricing and policies
- [ ] Booking pages accessible
- [ ] Payment provider configured (if using payments)
- [ ] Email notifications working (if enabled)
- [ ] Tested booking creation, cancellation, and rescheduling
- [ ] Production environment variables set

---

## 🎉 You're Ready!

Your scheduling system is now fully integrated. Users you create will automatically get Member records, and they'll be ready to accept bookings once you set up their schedules and event types.

For questions or issues, check the documentation or create an issue on GitHub.
