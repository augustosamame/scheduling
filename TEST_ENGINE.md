# Testing the Scheduling Engine

You can test this engine directly in this repository using the built-in **dummy app** located at `test/dummy/`.

## Quick Start

### 1. Database is already set up!
The database has already been created and migrated with sample data.

### 2. Test in Rails Console

```bash
rvm 3.3.4@scheduling do bin/rails console
```

### 3. Try These Examples

```ruby
# Get the organization
org = Scheduling::Organization.first
# => Clinica Lima

# Get a member (doctor)
member = Scheduling::Member.first
# => Dr. Maria Rodriguez, Cardiologist

# Get an event type (appointment type)
event_type = member.event_types.first
# => "Cardiology Consultation" - 30 minutes, 150 PEN

# Check availability for the next week
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))
puts "Available slots: #{slots.count}"

# View the first few available slots
slots.first(5).each do |slot|
  puts "#{slot[:start_time].strftime('%A, %B %d at %I:%M %p')}"
end

# Check if a specific time is available
time = Time.current.tomorrow.change(hour: 10, min: 0)
available = checker.available_at?(time, 30)
puts "Tomorrow at 10 AM available? #{available}"

# Create a booking
client = Scheduling::Client.first
booking = Scheduling::Booking.create!(
  event_type: event_type,
  member: member,
  client: client,
  start_time: slots.first[:start_time],
  timezone: 'America/Lima',
  status: 'confirmed',
  locale: 'es'
)

# Add answers to custom questions
event_type.booking_questions.each do |question|
  booking.booking_answers.create!(
    booking_question: question,
    answer: "Sample answer for: #{question.label}"
  )
end

# Test cancellation
booking.can_cancel?  # => true (if within policy)
# booking.cancel!(reason: "Patient requested", initiated_by: 'client')

# Test rescheduling
booking.can_reschedule?  # => true (if within policy)
new_time = slots.second[:start_time]
# new_booking = booking.reschedule_to!(new_time, reason: "Client requested", initiated_by: 'client')
```

## Exploring the Data

```ruby
# View all organizations
Scheduling::Organization.all

# View all members
Scheduling::Member.all.each do |m|
  puts "#{m.user.full_name} - #{m.title} (#{m.role})"
end

# View schedules
member = Scheduling::Member.first
schedule = member.default_schedule
schedule.availabilities.ordered.each do |avail|
  puts "#{avail.day_name}: #{avail.start_time.strftime('%I:%M %p')} - #{avail.end_time.strftime('%I:%M %p')}"
end

# Create a date override (mark a day as unavailable)
member.date_overrides.create!(
  date: Date.today + 3.days,
  unavailable: true,
  reason: "Holiday"
)

# Or set custom hours for a specific date
member.date_overrides.create!(
  date: Date.today + 5.days,
  start_time: "14:00",
  end_time: "18:00",
  unavailable: false,
  reason: "Afternoon only"
)
```

## Reset Sample Data

If you want to reset the sample data:

```bash
rvm 3.3.4@scheduling do bin/rails db:seed:replant
```

## Run the Development Server

You can also run the dummy app as a web server:

```bash
rvm 3.3.4@scheduling do bin/rails server
```

Then visit: http://localhost:3000

## Database Management

```bash
# Reset database
rvm 3.3.4@scheduling do bin/rails db:reset

# Run migrations only
rvm 3.3.4@scheduling do bin/rails db:migrate

# Rollback last migration
rvm 3.3.4@scheduling do bin/rails db:rollback

# Check migration status
rvm 3.3.4@scheduling do bin/rails db:migrate:status
```

## Sample Data Created

The seed file creates:
- **1 Organization**: "Clinica Lima"
- **1 Location**: "Downtown Clinic"
- **1 Team**: "Cardiology"
- **2 Members (Doctors)**: Dr. Maria Rodriguez (admin), Dr. Juan Lopez
- **1 Event Type**: "Cardiology Consultation" (30 min, 150 PEN)
- **Custom Questions**: Reason for visit, Allergies
- **1 Schedule**: Monday-Friday, 9 AM - 5 PM
- **1 Sample Client**: Carlos Mendoza

## What's Working

✅ Multi-tenant organization hierarchy
✅ Member schedules with weekly availability
✅ Date overrides for special hours/holidays
✅ Event types with duration, pricing, and policies
✅ Availability checking with buffers and conflicts
✅ Custom booking questions
✅ Booking lifecycle (create, cancel, reschedule)
✅ Multi-currency support (when money-rails is installed)

## What's Not Yet Implemented

⏳ Payment processing (Stripe/Culqi services)
⏳ Calendar sync (Google/Outlook integration)
⏳ Email notifications
⏳ Public booking controllers/views
⏳ Background jobs

## Using in a Host Application

To use this engine in a real Rails app:

1. Add to Gemfile:
   ```ruby
   gem 'scheduling', path: '../scheduling'
   # or from git:
   # gem 'scheduling', git: 'https://github.com/youruser/scheduling'
   ```

2. Install migrations:
   ```bash
   rails scheduling:install:migrations
   rails db:migrate
   ```

3. Create a User model if you don't have one
4. Mount the engine in `config/routes.rb` (when controllers are added):
   ```ruby
   mount Scheduling::Engine => "/scheduling"
   ```
