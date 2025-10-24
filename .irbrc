# Custom IRB configuration for Scheduling engine development

# Load awesome_print if available
begin
  require 'awesome_print'
  AwesomePrint.irb!
rescue LoadError
  # Not available, that's okay
end

# Helper methods for quick testing
def reload!
  load 'config/environment.rb'
end

def sample_org
  @sample_org ||= Scheduling::Organization.first
end

def sample_member
  @sample_member ||= Scheduling::Member.first
end

def sample_event_type
  @sample_event_type ||= Scheduling::EventType.first
end

def check_slots(days = 7)
  member = sample_member
  event_type = sample_event_type
  checker = Scheduling::AvailabilityChecker.new(member, event_type)
  slots = checker.available_slots(Date.today..(Date.today + days))
  puts "Found #{slots.count} available slots in next #{days} days"
  slots.first(5).each { |s| puts "  - #{s[:start_time].strftime('%a %b %d at %I:%M %p')}" }
  slots
end

puts "🗓️  Scheduling Engine Console"
puts "Helper methods: sample_org, sample_member, sample_event_type, check_slots"
