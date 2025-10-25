# =========================================================================
# Scheduling Engine - Initial Setup Script for Host Applications
# =========================================================================
#
# This script helps you quickly set up the organizational structure and
# initial data needed to start using the Scheduling engine.
#
# USAGE:
#   1. Copy this script to your host Rails app
#   2. Customize the values (organization name, emails, etc.)
#   3. Run in Rails console:
#      rails console
#      load 'setup_host_scheduling.rb'
#
# WHAT IT CREATES:
#   - Organization (multi-tenant container)
#   - Location (physical location)
#   - Team (department/specialty)
#   - Members (from existing Users)
#   - Schedules (weekly availability)
#   - Event Types (appointment types)
#   - Custom booking questions
#
# PREREQUISITES:
#   - User model with: first_name, last_name, email, title, bio
#   - At least one User record in your database
#   - Scheduling migrations installed and migrated
#
# =========================================================================
#
# CUSTOMIZE THESE VALUES FOR YOUR ORGANIZATION:

ORGANIZATION_NAME = "Clinica"
ORGANIZATION_SLUG = "clinica"
TIMEZONE = "America/Lima"
CURRENCY = "PEN"
LOCALE = "es"

LOCATION_NAME = "Sede Principal"
LOCATION_SLUG = "sede-principal"

TEAM_NAME = "Medicina General"
TEAM_SLUG = "medicina-general"

# Email of User who should be a member (doctor/provider)
MEMBER_USER_EMAIL = "doctor@clinica.com"
MEMBER_TITLE = "Médico General"
MEMBER_BIO = "Especialista en medicina general con amplia experiencia"

# Email of User who should be admin
ADMIN_USER_EMAIL = "admin@clinica.com"

# =========================================================================

puts "🏥 Setting up Scheduling data..."

# Step 1: Create Organization
org = Scheduling::Organization.find_or_create_by!(slug: ORGANIZATION_SLUG) do |o|
  o.name = ORGANIZATION_NAME
  o.timezone = TIMEZONE
  o.default_currency = CURRENCY
  o.default_locale = LOCALE
  o.description = "Medical clinic scheduling system"
end
puts "✅ Organization: #{org.name}"

# Step 2: Create Location
location = org.locations.find_or_create_by!(slug: LOCATION_SLUG) do |l|
  l.name = LOCATION_NAME
  l.address = "Av. Principal 123"
  l.city = "Lima"
  l.country = "Peru"
  l.postal_code = "15001"
  l.timezone = TIMEZONE
  l.phone = "+51 1 234 5678"
  l.email = "info@#{ORGANIZATION_SLUG}.com"
end
puts "✅ Location: #{location.name}"

# Step 3: Create Teams
team = location.teams.find_or_create_by!(slug: TEAM_SLUG) do |t|
  t.name = TEAM_NAME
  t.description = "Consultas de #{TEAM_NAME.downcase}"
  t.color = "#3b82f6"
end
puts "✅ Team: #{team.name}"

# Step 4: Create Members from existing Users
# Find users who should be doctors/members
doctor_user = User.find_by(email: MEMBER_USER_EMAIL)
admin_user = User.find_by(email: ADMIN_USER_EMAIL)

if doctor_user
  # Ensure user has title and bio
  unless doctor_user.title.present?
    doctor_user.update!(
      title: MEMBER_TITLE,
      bio: MEMBER_BIO
    )
  end

  member_doctor = team.members.find_or_create_by!(user: doctor_user) do |m|
    m.role = "member"
    m.active = true
    m.accepts_bookings = true
    # booking_slug will be auto-generated from user's name
  end
  puts "✅ Member created: #{member_doctor.user.first_name} #{member_doctor.user.last_name} (#{member_doctor.booking_slug})"

  # Step 5: Create Schedule for the doctor
  schedule = member_doctor.schedules.find_or_create_by!(name: "Horario Regular", is_default: true) do |s|
    s.timezone = TIMEZONE
  end

  # Add availability: Monday to Friday, 9 AM to 5 PM
  if schedule.availabilities.empty?
    (1..5).each do |day| # 1 = Monday, 5 = Friday
      schedule.availabilities.create!(
        day_of_week: day,
        start_time: "09:00",
        end_time: "17:00"
      )
    end
    puts "✅ Schedule created with availability Mon-Fri 9am-5pm"
  end

  # Step 6: Create Event Types
  if member_doctor.event_types.empty?
    consultation = member_doctor.event_types.create!(
      title: "Consulta Médica General",
      slug: "consulta-general",
      description: "Consulta médica de medicina general",
      location_type: "in_person",
      location_details: "Sede Principal - Consultorio 1",
      duration_minutes: 30,
      buffer_before_minutes: 5,
      buffer_after_minutes: 10,
      minimum_notice_hours: 2,
      maximum_days_in_future: 60,
      color: "#3b82f6",
      active: true,
      requires_payment: true,
      price_cents: 10000, # 100 in currency units
      price_currency: CURRENCY,
      payment_required_to_book: false, # Can pay later
      allow_rescheduling: true,
      rescheduling_policy_hours: 24,
      allow_cancellation: true,
      cancellation_policy_hours: 24
    )
    puts "✅ Event Type created: #{consultation.title}"

    # Add custom questions
    consultation.booking_questions.create!(
      label: "¿Motivo de la consulta?",
      question_type: "textarea",
      required: true,
      position: 1,
      placeholder: "Describa brevemente el motivo de su visita",
      help_text: "Esto ayuda al médico a prepararse para su consulta"
    )

    consultation.booking_questions.create!(
      label: "¿Tiene alguna alergia?",
      question_type: "text",
      required: false,
      position: 2,
      placeholder: "Indique alergias conocidas"
    )
    puts "✅ Custom questions added"
  end
else
  puts "⚠️  No doctor user found. Create a user with email 'doctor@clinica.com' first."
end

if admin_user
  # Ensure admin has title and bio
  unless admin_user.title.present?
    admin_user.update!(
      title: "Administrador",
      bio: "Administrador del sistema de citas"
    )
  end

  member_admin = team_medicina.members.find_or_create_by!(user: admin_user) do |m|
    m.role = "admin"
    m.active = true
    m.accepts_bookings = false # Admin doesn't accept bookings
  end
  puts "✅ Admin member created: #{member_admin.user.first_name} #{member_admin.user.last_name}"
end

# Summary
puts "\n📊 Summary:"
puts "  Organizations: #{Scheduling::Organization.count}"
puts "  Locations: #{Scheduling::Location.count}"
puts "  Teams: #{Scheduling::Team.count}"
puts "  Members: #{Scheduling::Member.count}"
puts "  Event Types: #{Scheduling::EventType.count}"
puts "  Schedules: #{Scheduling::Schedule.count}"
puts "  Availabilities: #{Scheduling::Availability.count}"

# Test availability
if doctor_member = Scheduling::Member.where(accepts_bookings: true).first
  puts "\n🧪 Testing availability checker..."
  event_type = doctor_member.event_types.active.first
  if event_type
    checker = Scheduling::AvailabilityChecker.new(doctor_member, event_type)
    slots = checker.available_slots(Date.today..(Date.today + 7))
    puts "  Found #{slots.count} available slots in the next 7 days"

    if slots.any?
      puts "\n🎯 First available slot: #{slots.first[:start_time].strftime('%Y-%m-%d %H:%M')}"
      puts "\n✅ Ready to accept bookings!"
      puts "   URL: http://localhost:3000/scheduling/#{org.slug}/#{doctor_member.booking_slug}"
    end
  end
end

puts "\n🎉 Setup complete!"
