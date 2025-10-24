module Scheduling
  class CalendarSyncJob < ApplicationJob
    queue_as :default

    def perform(booking_id, action, new_booking_id = nil)
      booking = Scheduling::Booking.find(booking_id)
      member = booking.member

      # Sync with each active calendar connection
      member.calendar_connections.active.each do |connection|
        next unless connection.add_bookings_to_calendar

        service = case connection.provider
                  when 'google'
                    GoogleCalendarService.new(connection)
                  when 'outlook'
                    OutlookCalendarService.new(connection)
                  else
                    next
                  end

        case action
        when 'create'
          service.add_booking(booking)
        when 'update'
          if new_booking_id
            new_booking = Scheduling::Booking.find(new_booking_id)
            service.delete_booking(booking) # Delete old
            service.add_booking(new_booking) # Add new
          else
            service.update_booking(booking)
          end
        when 'delete'
          service.delete_booking(booking)
        end
      rescue StandardError => e
        Rails.logger.error("Calendar sync failed for #{connection.provider}: #{e.message}")
        # Don't fail the job, just log the error
      end
    end
  end
end
