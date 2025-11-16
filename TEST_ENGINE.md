# Testing the Scheduling Engine

This guide shows how to test the engine itself using the built-in **dummy app** at `test/dummy/`.

## Prerequisites

- RVM with Ruby 3.3.4
- PostgreSQL installed and running
- Gemset: `rvm use 3.3.4@scheduling`

---

## 🚀 Quick Start

### Step 1: Initial Setup

```bash
cd /path/to/scheduling

# Make sure you're using the correct Ruby and gemset
rvm use 3.3.4@scheduling

# Install dependencies
bundle install
```

### Step 2: Setup Database

```bash
# Drop, create, and load schema
rvm 3.3.4@scheduling do bin/rails db:drop db:create db:seed (delete schema.rb first if needed)

# Run seeds to create test data
rvm 3.3.4@scheduling do bin/rails db:seed
```

**Expected Output:**
```
================================================================================
TESTING AUTOMATIC MEMBER SYNC (v0.2.0)
================================================================================

📝 Creating Users...
   (Watch as Members are AUTO-CREATED via callbacks! ✨)

   ✅ Created User: Dr. Maria Rodriguez
   ✅ Created User: Dr. Juan Lopez

🔍 Verifying Auto-Sync Results...
   ✅ SUCCESS! Members auto-created:
      - Dr. Maria Rodriguez (slug: dr-maria-rodriguez)
      - Dr. Juan Lopez (slug: dr-juan-lopez)

   ✅ Auto-created Organization: Test Clinic (test-clinic)
   ✅ Auto-created Location: Sede Principal
   ✅ Auto-created Team: Equipo por defecto

================================================================================
AUTO-SYNC WORKING PERFECTLY! 🎉
================================================================================
```

### Step 3: Open Rails Console

```bash
rvm 3.3.4@scheduling do bin/rails console
```

---

## 🧪 Testing Automatic Member Sync (v0.2.0 Feature)

### Test 1: Verify Auto-Created Data

```ruby
# Check users
User.count
# => 2

# Check members (auto-created!)
Scheduling::Member.count
# => 2

# Verify the sync
user = User.first
member = Scheduling::Member.find_by(user: user)

puts "User: #{user.full_name}"
# => "User: Dr. Maria Rodriguez"

puts "Member: #{member.full_name}"
# => "Member: Dr. Maria Rodriguez"

puts "Booking slug: #{member.booking_slug}"
# => "Booking slug: dr-maria-rodriguez"

puts "Organization: #{Scheduling::Organization.first.name}"
# => "Organization: Test Clinic"

puts "Location: #{member.team.location.name}"
# => "Location: Sede Principal"

puts "Team: #{member.team.name}"
# => "Team: Equipo por defecto"
```

### Test 2: Create a New User - Auto-Sync in Action

```ruby
# Create a new user - Member auto-created via callback!
new_user = User.create!(
  first_name: "Dr. Carlos",
  last_name: "Martinez",
  email: "carlos@test.com",
  title: "General Practitioner",
  bio: "Family medicine specialist"
)

# Check if Member was auto-created
new_member = Scheduling::Member.find_by(user: new_user)

puts "Auto-created: #{new_member.present? ? 'YES! ✅' : 'NO ❌'}"
# => "Auto-created: YES! ✅"

puts "Booking slug: #{new_member.booking_slug}"
# => "Booking slug: dr-carlos-martinez"

puts "Team: #{new_member.team.name}"
# => "Team: Equipo por defecto"
```

### Test 3: Update User - Verify Sync

```ruby
# Update user name
user = User.first
user.update!(first_name: "Dra. Maria Elena")

# Member reflects change via delegation
member = Scheduling::Member.find_by(user: user)
puts "Member name: #{member.full_name}"
# => "Member name: Dra. Maria Elena Rodriguez"

# booking_slug stays stable (doesn't change)
puts "Booking slug: #{member.booking_slug}"
# => "Booking slug: dr-maria-rodriguez" (unchanged!)
```

---

## 📅 Testing Availability System

### Get Available Slots

```ruby
member = Scheduling::Member.first
event_type = member.event_types.first

# Create availability checker
checker = Scheduling::AvailabilityChecker.new(member, event_type)

# Get available slots for next 7 days
slots = checker.available_slots(Date.today..(Date.today + 7))

puts "Available slots: #{slots.count}"

# View first 5 slots
slots.first(5).each do |slot|
  puts slot[:start_time].strftime('%A, %B %d at %I:%M %p')
end
```

### Check Specific Time

```ruby
# Check if tomorrow at 10 AM is available
time = Time.current.tomorrow.change(hour: 10, min: 0)
available = checker.available_at?(time, 30)

puts "Tomorrow at 10 AM available? #{available}"
```

### Add Date Override (Holiday)

```ruby
member = Scheduling::Member.first

# Mark a day as unavailable
member.date_overrides.create!(
  date: Date.today + 3.days,
  unavailable: true,
  reason: "Holiday"
)

# Set custom hours for a specific date
member.date_overrides.create!(
  date: Date.today + 5.days,
  start_time: "14:00",
  end_time: "18:00",
  unavailable: false,
  reason: "Afternoon only"
)

# Check availability again - holidays should be excluded
slots = checker.available_slots(Date.today..(Date.today + 7))
```

---

## 📋 Testing Booking Lifecycle

### Create a Booking

```ruby
member = Scheduling::Member.first
event_type = member.event_types.first
client = Scheduling::Client.first

# Get available slots
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))

# Create booking
booking = Scheduling::Booking.create!(
  event_type: event_type,
  member: member,
  client: client,
  start_time: slots.first[:start_time],
  timezone: 'America/Lima',
  status: 'confirmed',
  locale: 'es'
)

puts "Booking created: #{booking.uid}"
```

### Answer Custom Questions

```ruby
event_type.booking_questions.each do |question|
  booking.booking_answers.create!(
    booking_question: question,
    answer: "Sample answer for: #{question.label}"
  )
end

puts "Answered #{booking.booking_answers.count} questions"
```

### Test Cancellation

```ruby
booking.can_cancel?
# => true (if within policy hours)

# Cancel the booking
booking.cancel!(
  reason: "Patient requested",
  initiated_by: 'client'
)

puts "Booking status: #{booking.status}"
# => "Booking status: cancelled"
```

### Test Rescheduling

```ruby
# Create a new booking
booking = Scheduling::Booking.create!(
  event_type: event_type,
  member: member,
  client: client,
  start_time: slots.first[:start_time],
  timezone: 'America/Lima',
  status: 'confirmed',
  locale: 'es'
)

booking.can_reschedule?
# => true (if within policy)

# Reschedule to a new time
new_time = slots.second[:start_time]
new_booking = booking.reschedule_to!(
  new_time,
  reason: "Client requested",
  initiated_by: 'client'
)

puts "Original booking status: #{booking.reload.status}"
# => "Original booking status: rescheduled"

puts "New booking time: #{new_booking.start_time}"
```

---

## 🔍 Exploring the Data Model

### View Organization Hierarchy

```ruby
org = Scheduling::Organization.first
puts "Organization: #{org.name}"

org.locations.each do |location|
  puts "  Location: #{location.name}"

  location.teams.each do |team|
    puts "    Team: #{team.name}"

    team.members.each do |member|
      puts "      Member: #{member.full_name} (#{member.role})"
    end
  end
end
```

### View Member Schedule

```ruby
member = Scheduling::Member.first
schedule = member.default_schedule

schedule.availabilities.ordered.each do |avail|
  puts "#{avail.day_name}: #{avail.start_time.strftime('%I:%M %p')} - #{avail.end_time.strftime('%I:%M %p')}"
end
```

### View Event Types

```ruby
Scheduling::EventType.all.each do |et|
  puts "#{et.title} - #{et.duration_minutes} min - #{et.price_cents / 100.0} #{et.price_currency}"
end
```

---

## 🎯 Helper Methods in Console

The `.irbrc` file provides these helper methods:

```ruby
# Quick access to sample data
sample_organization  # => Scheduling::Organization.first
sample_member        # => Scheduling::Member.first
sample_event_type    # => Scheduling::EventType.first

# Check availability for next N days
check_slots(7)  # Shows available slots for next 7 days
```

---

## 🗄️ Database Management

### Reset Everything

```bash
# Drop, create, migrate, and seed
rvm 3.3.4@scheduling do bin/rails db:reset
```

### Just Reseed Data

```bash
# Keep database, just reset data
rvm 3.3.4@scheduling do bin/rails db:seed:replant
```

### Schema Operations

```bash
# Check migration status
rvm 3.3.4@scheduling do bin/rails db:migrate:status

# Rollback last migration
rvm 3.3.4@scheduling do bin/rails db:rollback

# Load schema (faster than migrate)
rvm 3.3.4@scheduling do bin/rails db:schema:load
```

---

## 🌐 Run the Dummy App Server

```bash
rvm 3.3.4@scheduling do bin/rails server
```

Visit: http://localhost:3000

**Note:** The engine is mounted at `/book` to mirror real-world usage and avoid route conflicts.

---

## 🔗 Public Booking URLs

Once the server is running, visitors can schedule appointments using these URL patterns:

### URL Patterns

**List all event types for a member:**
```
/book/:organization_slug/:member_booking_slug
```

**Book a specific event type:**
```
/book/:organization_slug/:member_booking_slug/:event_slug/book
```

### Example URLs (using seed data)

With the dummy app's seed data:
- Organization slug: `test-clinic`
- Member booking slug: `dr-maria-rodriguez`
- Event type slug: `general-appointment`

**View Dr. Rodriguez's available appointment types:**
```
http://localhost:3000/book/test-clinic/dr-maria-rodriguez
```

**Book a General Appointment with Dr. Rodriguez:**
```
http://localhost:3000/book/test-clinic/dr-maria-rodriguez/general-appointment/book
```

### Get URLs Programmatically

```ruby
member = Scheduling::Member.first
org = Scheduling::Organization.first

# Base member URL (lists all event types)
base_url = "book/#{org.slug}/#{member.booking_slug}"
puts "Member page: http://localhost:3000/#{base_url}"
# => "Member page: http://localhost:3000/book/test-clinic/dr-maria-rodriguez"

# Generate booking URL for each event type
member.event_types.each do |event_type|
  booking_url = "book/#{org.slug}/#{member.booking_slug}/#{event_type.slug}/book"
  puts "#{event_type.title}: http://localhost:3000/#{booking_url}"
end
# => "General Appointment: http://localhost:3000/book/test-clinic/dr-maria-rodriguez/general-appointment/book"
```

### Self-Service URLs (Token-Based)

After creating a booking, customers receive secure URLs for managing their appointment:

```ruby
booking = Scheduling::Booking.last

# Confirmation page (public UID)
confirmation_url = "book/bookings/#{booking.uid}"
puts "Confirmation: http://localhost:3000/#{confirmation_url}"

# Cancel booking (secure token - sent via email)
cancel_url = "book/bookings/#{booking.cancellation_token}/cancel"
puts "Cancel URL: http://localhost:3000/#{cancel_url}"

# Reschedule booking (secure token - sent via email)
reschedule_url = "book/bookings/#{booking.reschedule_token}/reschedule"
puts "Reschedule URL: http://localhost:3000/#{reschedule_url}"
```

**Note:** These routes are defined in `config/routes.rb` and work with the `PublicBookingsController`. HTML/ERB templates need to be implemented for the full booking flow.

---

## ✅ What's Tested and Working

- ✅ **Automatic Member Sync** - Members created when Users are created/updated
- ✅ **Multi-tenant Hierarchy** - Organizations → Locations → Teams → Members
- ✅ **Schedules & Availability** - Weekly recurring schedules with date overrides
- ✅ **Availability Checking** - Smart slot generation with buffers and conflicts
- ✅ **Booking Lifecycle** - Create, cancel, reschedule with policy enforcement
- ✅ **Custom Questions** - Dynamic forms per event type
- ✅ **Delegation Pattern** - Member delegates to User for name/email/title/bio
- ✅ **Booking Slug** - Stable, SEO-friendly URLs that don't change
- ✅ **Multi-currency** - Price support with different currencies

---

## 🚧 Not Yet Implemented in Dummy App

- ⏳ Payment processing (Stripe/Culqi) - Services exist, need credentials
- ⏳ Calendar sync (Google/Outlook) - Services exist, need OAuth setup
- ⏳ Email notifications - Jobs exist, need mailer implementation
- ⏳ Public booking views - Controllers exist, need HTML/ERB templates

---

## 📝 Sample Data Created by Seeds

- **Organization**: Test Clinic
- **Location**: Sede Principal
- **Team**: Equipo por defecto
- **Members**: 2 (Dr. Maria Rodriguez, Dr. Juan Lopez)
- **Event Type**: Cardiology Consultation (30 min, 150 PEN)
- **Schedule**: Monday-Friday, 9 AM - 5 PM
- **Custom Questions**: 2 (Reason for visit, Allergies)
- **Client**: Carlos Mendoza

---

## 🐛 Troubleshooting

### Members not auto-creating?

Check configuration:
```ruby
Scheduling.configuration.auto_create_members
# => Should be true
```

Check if UserExtensions is included:
```ruby
User.included_modules.include?(Scheduling::UserExtensions)
# => Should be true
```

### Duplicate migration errors?

Remove copied migrations from `test/dummy/db/migrate/*scheduling*.rb` - the engine's migrations are loaded automatically.

### Database doesn't exist?

```bash
rvm 3.3.4@scheduling do bin/rails db:create
```

---

## 📚 Next Steps

Once you've tested the engine and understand how it works, see **IMPLEMENT_IN_PROJECT.md** for instructions on integrating it into your Rails application.
