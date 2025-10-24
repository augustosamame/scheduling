module Scheduling
  class AvailabilityChecker
    def initialize(member, event_type)
      @member = member
      @event_type = event_type
      @schedule = member.default_schedule
    end

    def available_slots(date_range, timezone = 'America/Lima')
      slots = []

      date_range.each do |date|
        # Check for date overrides first
        override = @member.date_overrides.find_by(date: date)

        if override&.unavailable?
          next
        elsif override
          slots.concat(generate_slots_for_override(date, override, timezone))
        else
          # Use weekly schedule
          availability = @schedule.availabilities.find_by(day_of_week: date.wday)
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

      current_time = tz.parse("#{date} #{availability.start_time}")
      end_time = tz.parse("#{date} #{availability.end_time}")

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

      current_time = tz.parse("#{date} #{override.start_time}")
      end_time = tz.parse("#{date} #{override.end_time}")

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
      override = @member.date_overrides.find_by(date: date)

      if override
        return false if override.unavailable?
        time_of_day = time.strftime('%H:%M:%S')
        return time_of_day >= override.start_time.strftime('%H:%M:%S') &&
               time_of_day < override.end_time.strftime('%H:%M:%S')
      end

      availability = @schedule.availabilities.find_by(day_of_week: date.wday)
      return false unless availability

      time_of_day = time.strftime('%H:%M:%S')
      time_of_day >= availability.start_time.strftime('%H:%M:%S') &&
        time_of_day < availability.end_time.strftime('%H:%M:%S')
    end

    def has_conflicts?(start_time, end_time)
      @member.bookings
             .confirmed
             .where('start_time < ? AND end_time > ?', end_time, start_time)
             .exists?
    end

    def has_external_calendar_conflicts?(start_time, end_time)
      @member.calendar_connections.active.each do |connection|
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
  end
end
