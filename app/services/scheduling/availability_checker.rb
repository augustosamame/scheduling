module Scheduling
  class AvailabilityChecker
    def initialize(member, event_type, preloaded_bookings: nil, preloaded_date_overrides: nil, preloaded_availabilities: nil, preloaded_calendar_connections: nil)
      @member = member
      @event_type = event_type
      @schedule = member.default_schedule
      @preloaded_bookings = preloaded_bookings
      @preloaded_date_overrides = preloaded_date_overrides
      @preloaded_availabilities = preloaded_availabilities
      @preloaded_calendar_connections = preloaded_calendar_connections
    end

    def available_slots(date_range, timezone = 'America/Lima')
      slots = []

      date_range.each do |date|
        # Check for date overrides first
        override = find_date_override(date)

        if override&.unavailable?
          next
        elsif override
          slots.concat(generate_slots_for_override(date, override, timezone))
        else
          # Use weekly schedule
          availability = find_availability(date.wday)
          slots.concat(generate_slots_for_availability(date, availability, timezone)) if availability
        end
      end

      # Filter out already booked slots
      filter_booked_slots(slots, timezone)
    end

    def available_at?(time, duration_minutes)
      # Apply buffers
      buffered_start = time - @event_type.buffer_before_minutes.minutes
      buffered_end = time + duration_minutes.minutes + @event_type.buffer_after_minutes.minutes

      # Check if within schedule
      return false unless within_schedule?(time)

      # Check for conflicts
      !has_conflicts?(buffered_start, buffered_end)
    end

    private

    def generate_slots_for_availability(date, availability, timezone)
      slots = []
      tz = ActiveSupport::TimeZone[timezone]

      # Use hour/min components to avoid timezone issues with time-only fields
      current_time = tz.local(date.year, date.month, date.day, availability.start_time.hour, availability.start_time.min)
      end_time = tz.local(date.year, date.month, date.day, availability.end_time.hour, availability.end_time.min)

      # Apply minimum notice
      minimum_time = Time.current + @event_type.minimum_notice_hours.hours
      current_time = [current_time, minimum_time].max

      # Apply maximum days in future
      maximum_time = Time.current + @event_type.maximum_days_in_future.days
      end_time = [end_time, maximum_time].min

      while current_time + @event_type.duration_minutes.minutes <= end_time
        # Check if slot passes minimum notice and is not in the past
        if current_time > minimum_time
          slots << {
            start_time: current_time,
            end_time: current_time + @event_type.duration_minutes.minutes,
            available: true
          }
        end

        current_time += @event_type.duration_minutes.minutes
      end

      slots
    end

    def generate_slots_for_override(date, override, timezone)
      return [] if override.unavailable?

      tz = ActiveSupport::TimeZone[timezone]
      slots = []

      # Use hour/min components to avoid timezone issues with time-only fields
      current_time = tz.local(date.year, date.month, date.day, override.start_time.hour, override.start_time.min)
      end_time = tz.local(date.year, date.month, date.day, override.end_time.hour, override.end_time.min)

      while current_time + @event_type.duration_minutes.minutes <= end_time
        slots << {
          start_time: current_time,
          end_time: current_time + @event_type.duration_minutes.minutes,
          available: true
        }
        current_time += @event_type.duration_minutes.minutes
      end

      slots
    end

    def filter_booked_slots(slots, timezone)
      slots.each do |slot|
        slot[:available] = !has_conflicts?(
          slot[:start_time] - @event_type.buffer_before_minutes.minutes,
          slot[:end_time] + @event_type.buffer_after_minutes.minutes
        )

        # Check external calendar conflicts if enabled
        if slot[:available]
          slot[:available] = !has_external_calendar_conflicts?(
            slot[:start_time],
            slot[:end_time]
          )
        end
      end

      slots.select { |slot| slot[:available] }
    end

    def within_schedule?(time)
      date = time.to_date
      override = find_date_override(date)

      if override
        return false if override.unavailable?
        time_of_day = time.strftime('%H:%M:%S')
        return time_of_day >= override.start_time.strftime('%H:%M:%S') &&
               time_of_day < override.end_time.strftime('%H:%M:%S')
      end

      availability = find_availability(date.wday)
      return false unless availability

      time_of_day = time.strftime('%H:%M:%S')
      time_of_day >= availability.start_time.strftime('%H:%M:%S') &&
        time_of_day < availability.end_time.strftime('%H:%M:%S')
    end

    def has_conflicts?(start_time, end_time)
      if @preloaded_bookings
        # Use in-memory check with preloaded bookings
        @preloaded_bookings.any? do |booking|
          booking.start_time < end_time && booking.end_time > start_time
        end
      else
        # Fall back to database query if bookings not preloaded
        @member.bookings
               .confirmed
               .where('start_time < ? AND end_time > ?', end_time, start_time)
               .exists?
      end
    end

    def has_external_calendar_conflicts?(start_time, end_time)
      active_calendar_connections.each do |connection|
        next unless connection.check_for_conflicts

        service = case connection.provider
                  when 'google'
                    GoogleCalendarService.new(connection)
                  when 'outlook'
                    OutlookCalendarService.new(connection)
                  end

        return true if service.has_conflicts?(start_time, end_time)
      end

      false
    end

    # Helper methods to use preloaded data or fall back to queries
    def find_date_override(date)
      if @preloaded_date_overrides
        @preloaded_date_overrides.find { |override| override.date == date }
      else
        @member.date_overrides.find_by(date: date)
      end
    end

    def find_availability(day_of_week)
      if @preloaded_availabilities
        @preloaded_availabilities.find { |avail| avail.day_of_week == day_of_week }
      else
        @schedule&.availabilities&.find_by(day_of_week: day_of_week)
      end
    end

    def active_calendar_connections
      @active_calendar_connections ||= begin
        if @preloaded_calendar_connections
          @preloaded_calendar_connections.select(&:active?)
        else
          @member.calendar_connections.active.to_a
        end
      end
    end
  end
end
