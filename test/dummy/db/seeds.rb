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

puts "Creating sample data..."

# Create Users
user1 = User.create!(
  first_name: "Dr. Maria",
  last_name: "Rodriguez",
  email: "maria.rodriguez@clinic.com",
  title: "Cardiologist",
  bio: "Specialist in preventive cardiology with 15 years of experience"
)

user2 = User.create!(
  first_name: "Dr. Juan",
  last_name: "Lopez",
  email: "juan.lopez@clinic.com",
  title: "Cardiologist",
  bio: "Expert in interventional cardiology"
)

# Create Organization
org = Scheduling::Organization.create!(
  name: "Clinica Lima",
  slug: "clinica-lima",
  timezone: "America/Lima",
  default_currency: "PEN",
  default_locale: "es",
  description: "Multi-specialty medical clinic in Lima"
)

# Create Location
location = org.locations.create!(
  name: "Downtown Clinic",
  slug: "downtown",
  address: "Av. Arequipa 1234",
  city: "Lima",
  state: "Lima",
  country: "Peru",
  postal_code: "15001",
  phone: "+51 1 234 5678",
  email: "downtown@clinicalima.com",
  timezone: "America/Lima"
)

# Create Team
team = location.teams.create!(
  name: "Cardiology",
  slug: "cardiology",
  description: "Heart and cardiovascular specialists",
  color: "#3b82f6"
)

# Create Members
member1 = team.members.create!(
  user: user1,
  role: "admin",
  active: true,
  accepts_bookings: true
)

member2 = team.members.create!(
  user: user2,
  role: "member",
  active: true,
  accepts_bookings: true
)

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
client = org.clients.create!(
  email: "patient@example.com",
  first_name: "Carlos",
  last_name: "Mendoza",
  phone: "+51 999 888 777",
  timezone: "America/Lima",
  locale: "es"
)

puts "\n✅ Sample data created successfully!"
puts "\n📊 Summary:"
puts "  - Organization: #{org.name}"
puts "  - Location: #{location.name}"
puts "  - Team: #{team.name}"
puts "  - Members: #{team.members.count}"
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
