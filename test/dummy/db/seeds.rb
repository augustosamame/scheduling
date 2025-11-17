# Clear existing data
puts "Clearing existing data..."

# Use delete_all in correct order (children first, then parents)
Scheduling::BookingAnswer.delete_all
Scheduling::BookingChange.delete_all
Scheduling::Payment.delete_all
Scheduling::Booking.delete_all
Scheduling::BookingQuestion.delete_all
Scheduling::Availability.delete_all
Scheduling::DateOverride.delete_all
Scheduling::EventType.delete_all
Scheduling::Schedule.delete_all
Scheduling::Member.delete_all
Scheduling::Client.delete_all
Scheduling::Team.delete_all
Scheduling::Location.delete_all
Scheduling::Organization.delete_all
User.delete_all

puts "\n" + "="*80
puts "TESTING AUTOMATIC MEMBER SYNC (v0.2.0)"
puts "="*80

puts "\n📝 Creating Users..."
puts "   (Watch as Members are AUTO-CREATED via callbacks! ✨)"
puts ""

# Create Users - Members will be AUTO-CREATED via callbacks!
user1 = User.create!(
  first_name: "Dr. Maria",
  last_name: "Rodriguez",
  email: "maria.rodriguez@clinic.com",
  title: "Cardiologist",
  bio: "Specialist in preventive cardiology with 15 years of experience"
)
puts "   ✅ Created User: #{user1.full_name}"

user2 = User.create!(
  first_name: "Dr. Juan",
  last_name: "Lopez",
  email: "juan.lopez@clinic.com",
  title: "Cardiologist",
  bio: "Expert in interventional cardiology"
)
puts "   ✅ Created User: #{user2.full_name}"

# Verify Members were auto-created
puts "\n🔍 Verifying Auto-Sync Results..."
member1 = Scheduling::Member.find_by(user: user1)
member2 = Scheduling::Member.find_by(user: user2)

if member1 && member2
  puts "   ✅ SUCCESS! Members auto-created:"
  puts "      - #{member1.full_name} (slug: #{member1.booking_slug})"
  puts "      - #{member2.full_name} (slug: #{member2.booking_slug})"

  # Get auto-created resources
  org = Scheduling::Organization.first
  location = Scheduling::Location.first
  team = Scheduling::Team.first

  puts "\n   ✅ Auto-created Organization: #{org.name} (#{org.slug})"
  puts "   ✅ Auto-created Location: #{location.name}"
  puts "   ✅ Auto-created Team: #{team.name}"

  puts "\n" + "="*80
  puts "AUTO-SYNC WORKING PERFECTLY! 🎉"
  puts "="*80
else
  puts "   ❌ FAILED! Members were not auto-created"
  puts "      Check that config.auto_create_members = true in initializer"
  abort
end

# Create admin users for testing the admin system
puts "\n👥 Creating admin users for testing..."

# Update existing member to be a regular member
member1.update!(role: 'member')

# Create test user for admin
admin_user = User.create!(
  first_name: "Admin",
  last_name: "User",
  email: "admin@test.com",
  title: "System Administrator",
  bio: "Full access administrator"
)

# Find the auto-created member and update role to admin
admin_member = Scheduling::Member.find_by(user: admin_user)
admin_member.update!(
  role: 'admin',
  booking_slug: 'admin-user',
  active: true,
  accepts_bookings: false
)

# Create manager user
manager_user = User.create!(
  first_name: "Manager",
  last_name: "User",
  email: "manager@test.com",
  title: "Location Manager",
  bio: "Manages location and teams"
)

manager_member = Scheduling::Member.find_by(user: manager_user)
manager_member.update!(
  role: 'manager',
  booking_slug: 'manager-user',
  active: true,
  accepts_bookings: false
)

# Create a regular doctor user for member testing
doctor_user = User.create!(
  first_name: "Dr. Carlos",
  last_name: "Gomez",
  email: "doctor@test.com",
  title: "General Practitioner",
  bio: "Family medicine specialist"
)

doctor_member = Scheduling::Member.find_by(user: doctor_user)
doctor_member.update!(
  role: 'member',
  booking_slug: 'dr-carlos-gomez',
  active: true,
  accepts_bookings: true
)

puts "   ✅ Admin user: #{admin_user.email} (role: #{admin_member.role})"
puts "   ✅ Manager user: #{manager_user.email} (role: #{manager_member.role})"
puts "   ✅ Member user: #{doctor_user.email} (role: #{doctor_member.role})"

# Now continue with additional setup (schedules, event types, etc.)
puts "\n📅 Setting up schedules and event types..."

# Use the auto-created default schedule or create a new one
schedule1 = doctor_member.default_schedule || doctor_member.schedules.create!(
  name: "Regular Hours",
  timezone: "America/Lima",
  is_default: true
)

# Add availabilities (Monday to Friday, 9 AM to 5 PM)
(1..5).each do |day|
  schedule1.availabilities.create!(
    day_of_week: day,
    start_time: "09:00",
    end_time: "17:00"
  )
end

# Create Event Types for the doctor member
consultation = doctor_member.event_types.create!(
  title: "Cardiology Consultation",
  slug: "cardiology-consultation",
  description: "Initial consultation for heart health evaluation",
  location_type: "in_person",
  location_details: "Clinica Lima - Downtown, Room 301",
  duration_minutes: 30,
  buffer_before_minutes: 5,
  buffer_after_minutes: 5,
  minimum_notice_hours: 24,
  maximum_days_in_future: 60,
  color: "#3b82f6",
  active: true,
  requires_payment: true,
  price_cents: 15000, # 150 PEN
  price_currency: "PEN",
  payment_required_to_book: false,
  allow_rescheduling: true,
  rescheduling_policy_hours: 24,
  allow_cancellation: true,
  cancellation_policy_hours: 24
)

# Add custom questions to the event type
consultation.booking_questions.create!(
  label: "What is the reason for your visit?",
  question_type: "textarea",
  required: true,
  position: 1,
  placeholder: "Please describe your symptoms or reason for consultation",
  help_text: "This helps the doctor prepare for your visit"
)

consultation.booking_questions.create!(
  label: "Do you have any allergies?",
  question_type: "text",
  required: false,
  position: 2,
  placeholder: "List any known allergies"
)

# Create a sample client
client = Scheduling::Organization.first.clients.create!(
  email: "patient@example.com",
  first_name: "Carlos",
  last_name: "Mendoza",
  phone: "+51 999 888 777",
  timezone: "America/Lima",
  locale: "es"
)

puts "\n✅ Sample data created successfully!"
puts "\n📊 Summary:"
puts "  - Organization: #{Scheduling::Organization.first.name}"
puts "  - Location: #{Scheduling::Location.first.name}"
puts "  - Team: #{Scheduling::Team.first.name}"
puts "  - Members: #{Scheduling::Member.count}"
puts "  - Event Types: #{doctor_member.event_types.count}"
puts "  - Schedule with #{schedule1.availabilities.count} availability slots"
puts "  - Sample client: #{client.full_name}"

puts "\n👥 Admin Users (for testing admin panel):"
puts ""
puts "  ┌─────────────────────────────────────────┐"
puts "  │ LOGIN CREDENTIALS                       │"
puts "  ├─────────────────────────────────────────┤"
puts "  │ Admin:   admin@test.com                 │"
puts "  │ Role:    admin                          │"
puts "  │ Access:  Full organization              │"
puts "  ├─────────────────────────────────────────┤"
puts "  │ Manager: manager@test.com               │"
puts "  │ Role:    manager                        │"
puts "  │ Access:  Location #{location.name.ljust(21)} │"
puts "  ├─────────────────────────────────────────┤"
puts "  │ Member:  doctor@test.com                │"
puts "  │ Role:    member                         │"
puts "  │ Access:  Own bookings only              │"
puts "  └─────────────────────────────────────────┘"
puts ""
puts "  Admin panel: http://localhost:3000/book/admin"

puts "\n🚀 Try it in the console:"
puts "  rvm 3.3.4@scheduling do bin/rails console"
puts "\nThen try:"
puts "  org = Scheduling::Organization.first"
puts "  member = Scheduling::Member.first"
puts "  event_type = member.event_types.first"
puts "  checker = Scheduling::AvailabilityChecker.new(member, event_type)"
puts "  slots = checker.available_slots(Date.today..(Date.today + 7))"
puts '  puts "Available slots: #{slots.count}"'
