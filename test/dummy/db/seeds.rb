# Clear existing data
puts "Limpiando datos existentes..."

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
puts "PROBANDO SINCRONIZACIÓN AUTOMÁTICA DE MIEMBROS (v0.2.0)"
puts "="*80

puts "\n📝 Creando Usuarios..."
puts "   (¡Observa cómo los Miembros se CREAN AUTOMÁTICAMENTE mediante callbacks! ✨)"
puts ""

# Create Users - Members will be AUTO-CREATED via callbacks!
user1 = User.create!(
  first_name: "Dr. Maria",
  last_name: "Rodriguez",
  email: "maria.rodriguez@clinic.com",
  title: "Cardióloga",
  bio: "Especialista en cardiología preventiva con 15 años de experiencia"
)
puts "   ✅ Usuario creado: #{user1.full_name}"

user2 = User.create!(
  first_name: "Dr. Juan",
  last_name: "Lopez",
  email: "juan.lopez@clinic.com",
  title: "Cardiólogo",
  bio: "Experto en cardiología intervencionista"
)
puts "   ✅ Usuario creado: #{user2.full_name}"

# Verify Members were auto-created
puts "\n🔍 Verificando Resultados de Auto-Sincronización..."
member1 = Scheduling::Member.find_by(user: user1)
member2 = Scheduling::Member.find_by(user: user2)

if member1 && member2
  puts "   ✅ ¡ÉXITO! Miembros creados automáticamente:"
  puts "      - #{member1.full_name} (slug: #{member1.booking_slug})"
  puts "      - #{member2.full_name} (slug: #{member2.booking_slug})"

  # Get auto-created resources
  org = Scheduling::Organization.first
  location = Scheduling::Location.first
  team = Scheduling::Team.first

  puts "\n   ✅ Organización creada automáticamente: #{org.name} (#{org.slug})"
  puts "   ✅ Ubicación creada automáticamente: #{location.name}"
  puts "   ✅ Equipo creado automáticamente: #{team.name}"

  puts "\n" + "="*80
  puts "¡AUTO-SINCRONIZACIÓN FUNCIONANDO PERFECTAMENTE! 🎉"
  puts "="*80
else
  puts "   ❌ ¡FALLÓ! Los miembros no fueron creados automáticamente"
  puts "      Verifica que config.auto_create_members = true en el inicializador"
  abort
end

# Create admin users for testing the admin system
puts "\n👥 Creando usuarios administradores para pruebas..."

# Update existing member to be a regular member
member1.update!(role: "member")

# Create test user for admin
admin_user = User.create!(
  first_name: "Admin",
  last_name: "User",
  email: "admin@test.com",
  title: "Administrador del Sistema",
  bio: "Administrador con acceso completo"
)

# Find the auto-created member and update role to admin
admin_member = Scheduling::Member.find_by(user: admin_user)
admin_member.update!(
  role: "admin",
  booking_slug: "admin-user",
  active: true,
  accepts_bookings: false
)

# Create manager user
manager_user = User.create!(
  first_name: "Manager",
  last_name: "User",
  email: "manager@test.com",
  title: "Gerente de Ubicación",
  bio: "Gestiona ubicación y equipos"
)

manager_member = Scheduling::Member.find_by(user: manager_user)
manager_member.update!(
  role: "manager",
  booking_slug: "manager-user",
  active: true,
  accepts_bookings: false
)

# Create a regular doctor user for member testing
doctor_user = User.create!(
  first_name: "Dr. Carlos",
  last_name: "Gomez",
  email: "doctor@test.com",
  title: "Médico General",
  bio: "Especialista en medicina familiar"
)

doctor_member = Scheduling::Member.find_by(user: doctor_user)
doctor_member.update!(
  role: "member",
  booking_slug: "dr-carlos-gomez",
  active: true,
  accepts_bookings: true
)

puts "   ✅ Usuario admin: #{admin_user.email} (rol: #{admin_member.role})"
puts "   ✅ Usuario manager: #{manager_user.email} (rol: #{manager_member.role})"
puts "   ✅ Usuario member: #{doctor_user.email} (rol: #{doctor_member.role})"

# Now continue with additional setup (schedules, event types, etc.)
puts "\n📅 Configurando horarios y tipos de eventos..."

# Use the auto-created default schedule or create a new one
schedule1 = doctor_member.default_schedule || doctor_member.schedules.create!(
  name: "Horario Regular",
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
  title: "Consulta de Cardiología",
  slug: "cardiology-consultation",
  description: "Consulta inicial para evaluación de salud cardíaca",
  location_type: "in_person",
  location_address: "Av. Javier Prado 123",
  location_address_line_2: "Consultorio 301",
  location_city: "Lima",
  location_state: "Lima",
  location_postal_code: "15036",
  location_country: "Perú",
  location_latitude: -12.046374,
  location_longitude: -77.042793,
  location_instructions: "Estacionamiento disponible en el sótano. Use la entrada norte.",
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
  label: "¿Cuál es el motivo de su visita?",
  question_type: "textarea",
  required: true,
  position: 1,
  placeholder: "Por favor describa sus síntomas o motivo de consulta",
  help_text: "Esto ayuda al doctor a prepararse para su visita"
)

consultation.booking_questions.create!(
  label: "¿Tiene alguna alergia?",
  question_type: "text",
  required: false,
  position: 2,
  placeholder: "Liste cualquier alergia conocida"
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

puts "\n✅ ¡Datos de ejemplo creados exitosamente!"
puts "\n📊 Resumen:"
puts "  - Organización: #{Scheduling::Organization.first.name}"
puts "  - Ubicación: #{Scheduling::Location.first.name}"
puts "  - Equipo: #{Scheduling::Team.first.name}"
puts "  - Miembros: #{Scheduling::Member.count}"
puts "  - Tipos de Eventos: #{doctor_member.event_types.count}"
puts "  - Horario con #{schedule1.availabilities.count} espacios de disponibilidad"
puts "  - Cliente de ejemplo: #{client.full_name}"

puts "\n👥 Usuarios Admin (para probar el panel de administración):"
puts ""
puts "  ┌─────────────────────────────────────────┐"
puts "  │ CREDENCIALES DE ACCESO                  │"
puts "  ├─────────────────────────────────────────┤"
puts "  │ Admin:   admin@test.com                 │"
puts "  │ Rol:     admin                          │"
puts "  │ Acceso:  Organización completa          │"
puts "  ├─────────────────────────────────────────┤"
puts "  │ Manager: manager@test.com               │"
puts "  │ Rol:     manager                        │"
puts "  │ Acceso:  Ubicación #{location.name.ljust(21)} │"
puts "  ├─────────────────────────────────────────┤"
puts "  │ Member:  doctor@test.com                │"
puts "  │ Rol:     member                         │"
puts "  │ Acceso:  Solo sus propias reservas      │"
puts "  └─────────────────────────────────────────┘"
puts ""
puts "  Panel de admin: http://localhost:3000/book/admin"

puts "\n🚀 Pruébalo en la consola:"
puts "  rvm 3.3.4@scheduling do bin/rails console"
puts "\nLuego prueba:"
puts "  org = Scheduling::Organization.first"
puts "  member = Scheduling::Member.first"
puts "  event_type = member.event_types.first"
puts "  checker = Scheduling::AvailabilityChecker.new(member, event_type)"
puts "  slots = checker.available_slots(Date.today..(Date.today + 7))"
puts '  puts "Espacios disponibles: #{slots.count}"'
