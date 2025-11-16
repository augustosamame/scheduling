# Clear existing data
puts "Clearing existing data..."
Scheduling::Booking.destroy_all
Scheduling::EventType.destroy_all
Scheduling::Schedule.destroy_all
Scheduling::Member.destroy_all
Scheduling::Team.destroy_all
Scheduling::Location.destroy_all
Scheduling::Organization.destroy_all
Scheduling::Client.destroy_all
User.destroy_all

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

# Now continue with additional setup (schedules, event types, etc.)
puts "\n📅 Setting up schedules and event types..."

# Create Schedule for Member 1
schedule1 = member1.schedules.create!(
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

# Create Event Types
consultation = member1.event_types.create!(
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
puts "  - Event Types: #{member1.event_types.count}"
puts "  - Schedule with #{schedule1.availabilities.count} availability slots"
puts "  - Sample client: #{client.full_name}"

puts "\n🚀 Try it in the console:"
puts "  rvm 3.3.4@scheduling do bin/rails console"
puts "\nThen try:"
puts "  org = Scheduling::Organization.first"
puts "  member = Scheduling::Member.first"
puts "  event_type = member.event_types.first"
puts "  checker = Scheduling::AvailabilityChecker.new(member, event_type)"
puts "  slots = checker.available_slots(Date.today..(Date.today + 7))"
puts '  puts "Available slots: #{slots.count}"'
