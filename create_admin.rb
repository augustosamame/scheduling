# Script to create admin users for testing
org = Scheduling::Organization.first

unless org
  puts "❌ No organization found. Please run db:seed first."
  exit
end

location = org.locations.first
team = location.teams.first

# Create User for admin
admin_user = User.find_or_create_by!(email: 'admin@test.com') do |u|
  u.first_name = 'Admin'
  u.last_name = 'User'
  u.title = 'System Administrator'
  u.bio = 'Full access administrator'
end

# Find or create member with admin role
admin_member = Scheduling::Member.find_or_initialize_by(user: admin_user)
admin_member.update!(
  team: team,
  role: 'admin',
  booking_slug: 'admin-user',
  active: true,
  accepts_bookings: false
)

# Create manager user
manager_user = User.find_or_create_by!(email: 'manager@test.com') do |u|
  u.first_name = 'Manager'
  u.last_name = 'User'
  u.title = 'Location Manager'
  u.bio = 'Manages location and teams'
end

manager_member = Scheduling::Member.find_or_initialize_by(user: manager_user)
manager_member.update!(
  team: team,
  role: 'manager',
  booking_slug: 'manager-user',
  active: true,
  accepts_bookings: false
)

# Regular member user (already exists from seeds, just update role)
member_user = User.find_by(email: 'doctor@test.com')
if member_user
  member = Scheduling::Member.find_by(user: member_user)
  member.update!(role: 'member') if member
  puts "✅ Regular member updated: #{member_user.email}"
end

puts ''
puts '✅ Admin users created successfully!'
puts ''
puts '┌─────────────────────────────────────────┐'
puts '│ LOGIN CREDENTIALS                       │'
puts '├─────────────────────────────────────────┤'
puts "│ Admin:   admin@test.com                 │"
puts "│ Role:    #{admin_member.role.ljust(31)} │"
puts "│ Access:  Full organization              │"
puts '├─────────────────────────────────────────┤'
puts "│ Manager: manager@test.com               │"
puts "│ Role:    #{manager_member.role.ljust(31)} │"
puts "│ Access:  Location #{location.name.ljust(21)} │"
puts '├─────────────────────────────────────────┤'
puts "│ Member:  doctor@test.com                │"
puts "│ Role:    member                         │"
puts "│ Access:  Own bookings only              │"
puts '└─────────────────────────────────────────┘'
puts ''
puts 'Access the admin panel at: http://localhost:3000/book/admin'
puts ''
