namespace :scheduling do
  desc "Sync existing users to create Scheduling::Member records"
  task sync_existing_users: :environment do
    puts "🔄 Starting sync of existing users to Scheduling::Members..."
    puts "=" * 60

    # Check if auto_create_members is enabled
    unless Scheduling.configuration.auto_create_members
      puts "⚠️  WARNING: auto_create_members is disabled in configuration!"
      puts "   Enable it in config/initializers/scheduling.rb"
      puts "   Or run this task anyway? (y/n)"
      response = STDIN.gets.chomp.downcase
      exit unless response == 'y'
    end

    # Find all users without a scheduling member
    # This assumes User model exists in the host app
    unless defined?(User)
      puts "❌ ERROR: User model not found!"
      puts "   This task requires a User model in your application"
      exit 1
    end

    # Get all users
    total_users = User.count
    users_without_members = User.left_joins(:scheduling_members)
                                .where(scheduling_members: { id: nil })

    puts "📊 Statistics:"
    puts "   Total users: #{total_users}"
    puts "   Users without Members: #{users_without_members.count}"
    puts "   Users with Members: #{Scheduling::Member.count}"
    puts ""

    if users_without_members.empty?
      puts "✅ All users already have Scheduling::Member records!"
      puts "   Nothing to sync."
      exit 0
    end

    # Ask for confirmation
    puts "⚠️  This will create #{users_without_members.count} new Member records."
    puts "   Continue? (y/n)"
    response = STDIN.gets.chomp.downcase
    exit unless response == 'y'

    # Sync users
    success_count = 0
    error_count = 0
    errors = []

    puts ""
    puts "🚀 Syncing users..."
    puts ""

    users_without_members.find_each.with_index do |user, index|
      begin
        # Use the MemberSyncService to sync the user
        service = Scheduling::MemberSyncService.new(user)
        member = service.sync

        if member
          success_count += 1
          puts "✅ [#{index + 1}/#{users_without_members.count}] Synced: #{user.email} → Member ##{member.id} (#{member.booking_slug})"
        else
          error_count += 1
          puts "❌ [#{index + 1}/#{users_without_members.count}] Failed: #{user.email} - No member created"
          errors << { user: user.email, error: "Member not created" }
        end
      rescue => e
        error_count += 1
        puts "❌ [#{index + 1}/#{users_without_members.count}] Error: #{user.email} - #{e.message}"
        errors << { user: user.email, error: e.message }
      end
    end

    # Summary
    puts ""
    puts "=" * 60
    puts "🎉 Sync Complete!"
    puts ""
    puts "📊 Results:"
    puts "   Successfully synced: #{success_count}"
    puts "   Errors: #{error_count}"
    puts "   Total processed: #{success_count + error_count}"
    puts ""

    if errors.any?
      puts "⚠️  Errors encountered:"
      errors.each do |err|
        puts "   - #{err[:user]}: #{err[:error]}"
      end
      puts ""
    end

    # Final statistics
    puts "📈 Final Statistics:"
    puts "   Total Members: #{Scheduling::Member.count}"
    puts "   Total Organizations: #{Scheduling::Organization.count}"
    puts "   Total Locations: #{Scheduling::Location.count}"
    puts "   Total Teams: #{Scheduling::Team.count}"
    puts ""
    puts "✅ Done!"
  end

  desc "Sync a specific user by email to create Scheduling::Member"
  task :sync_user, [:email] => :environment do |t, args|
    unless args[:email]
      puts "❌ ERROR: Email required!"
      puts "   Usage: rails scheduling:sync_user[user@example.com]"
      exit 1
    end

    unless defined?(User)
      puts "❌ ERROR: User model not found!"
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "❌ ERROR: User not found with email: #{args[:email]}"
      exit 1
    end

    puts "🔄 Syncing user: #{user.email}"
    puts ""

    # Check if member already exists
    existing_member = Scheduling::Member.find_by(user: user)
    if existing_member
      puts "⚠️  Member already exists:"
      puts "   ID: #{existing_member.id}"
      puts "   Booking Slug: #{existing_member.booking_slug}"
      puts "   Team: #{existing_member.team.name}"
      puts "   Location: #{existing_member.team.location.name}"
      puts ""
      puts "   Update anyway? (y/n)"
      response = STDIN.gets.chomp.downcase
      exit unless response == 'y'
    end

    begin
      service = Scheduling::MemberSyncService.new(user)
      member = service.sync

      if member
        puts "✅ Successfully synced!"
        puts ""
        puts "📋 Member Details:"
        puts "   ID: #{member.id}"
        puts "   Booking Slug: #{member.booking_slug}"
        puts "   Role: #{member.role}"
        puts "   Team: #{member.team.name}"
        puts "   Location: #{member.team.location.name}"
        puts "   Organization: #{member.team.location.organization.name}"
        puts ""
        puts "🔗 Booking URL:"
        puts "   /#{member.team.location.organization.slug}/#{member.booking_slug}"
      else
        puts "❌ Failed to sync member"
        exit 1
      end
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Show statistics about Scheduling data"
  task stats: :environment do
    puts "📊 Scheduling Engine Statistics"
    puts "=" * 60
    puts ""

    if defined?(User)
      total_users = User.count
      users_with_members = User.joins(:scheduling_members).distinct.count
      users_without_members = total_users - users_with_members

      puts "👥 Users:"
      puts "   Total users: #{total_users}"
      puts "   Users with Members: #{users_with_members}"
      puts "   Users without Members: #{users_without_members}"
      puts ""
    end

    puts "🏢 Organizations: #{Scheduling::Organization.count}"
    puts "📍 Locations: #{Scheduling::Location.count}"
    puts "👔 Teams: #{Scheduling::Team.count}"
    puts "👤 Members: #{Scheduling::Member.count}"
    puts "👨‍👩‍👧‍👦 Clients: #{Scheduling::Client.count}"
    puts ""
    puts "🎫 Event Types: #{Scheduling::EventType.count}"
    puts "📅 Schedules: #{Scheduling::Schedule.count}"
    puts "🗓️  Date Overrides: #{Scheduling::DateOverride.count}"
    puts ""
    puts "📋 Bookings:"
    puts "   Total: #{Scheduling::Booking.count}"
    puts "   Confirmed: #{Scheduling::Booking.confirmed.count}"
    puts "   Cancelled: #{Scheduling::Booking.cancelled.count}"
    puts "   Completed: #{Scheduling::Booking.completed.count}"
    puts ""
    puts "💳 Payments: #{Scheduling::Payment.count}"
    puts "🔗 Calendar Connections: #{Scheduling::CalendarConnection.count}"
    puts ""
  end
end
