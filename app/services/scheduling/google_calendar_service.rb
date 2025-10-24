module Scheduling
  class GoogleCalendarService
    def initialize(calendar_connection)
      @connection = calendar_connection
      @member = calendar_connection.member
    end

    def add_booking(booking)
      return unless @connection.add_bookings_to_calendar?
      raise NotImplementedError, "Google Calendar API not available" unless google_api_available?

      client = authorized_client
      event = Google::Apis::CalendarV3::Event.new(
        summary: "#{booking.event_type.title} - #{booking.client.full_name}",
        description: booking.notes,
        start: {
          date_time: booking.start_time.iso8601,
          time_zone: booking.timezone
        },
        end: {
          date_time: booking.end_time.iso8601,
          time_zone: booking.timezone
        },
        attendees: [
          { email: booking.client.email, display_name: booking.client.full_name }
        ],
        reminders: {
          use_default: false,
          overrides: [
            { method: 'email', minutes: 24 * 60 },
            { method: 'popup', minutes: 30 }
          ]
        }
      )

      result = client.insert_event('primary', event)
      booking.update!(google_calendar_event_id: result.id)

      result
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to add booking to Google Calendar: #{e.message}")
      nil
    end

    def update_booking(booking)
      return unless booking.google_calendar_event_id.present?
      raise NotImplementedError, "Google Calendar API not available" unless google_api_available?

      client = authorized_client
      event = client.get_event('primary', booking.google_calendar_event_id)

      event.start.date_time = booking.start_time.iso8601
      event.end.date_time = booking.end_time.iso8601

      client.update_event('primary', event.id, event)
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to update Google Calendar event: #{e.message}")
    end

    def delete_booking(booking)
      return unless booking.google_calendar_event_id.present?
      raise NotImplementedError, "Google Calendar API not available" unless google_api_available?

      client = authorized_client
      client.delete_event('primary', booking.google_calendar_event_id)
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to delete Google Calendar event: #{e.message}")
    end

    def has_conflicts?(start_time, end_time)
      raise NotImplementedError, "Google Calendar API not available" unless google_api_available?

      client = authorized_client
      events = client.list_events(
        'primary',
        time_min: start_time.iso8601,
        time_max: end_time.iso8601,
        single_events: true
      )

      events.items.any?
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to check Google Calendar conflicts: #{e.message}")
      false
    end

    def refresh_token
      raise NotImplementedError, "Google Calendar API not available" unless google_api_available?

      # Implement OAuth token refresh logic
      # This is a placeholder - implement based on your OAuth setup
      auth_client = Signet::OAuth2::Client.new(
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        refresh_token: @connection.refresh_token
      )

      auth_client.refresh!

      @connection.update!(
        access_token: auth_client.access_token,
        token_expires_at: Time.current + auth_client.expires_in.seconds
      )
    rescue StandardError => e
      Rails.logger.error("Failed to refresh Google Calendar token: #{e.message}")
      false
    end

    private

    def authorized_client
      client = Google::Apis::CalendarV3::CalendarService.new
      client.authorization = authorization
      client
    end

    def authorization
      # Set up Google OAuth2 authorization
      auth = Signet::OAuth2::Client.new(
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        access_token: @connection.access_token,
        refresh_token: @connection.refresh_token,
        expires_at: @connection.token_expires_at
      )

      # Refresh if expired
      if @connection.token_expired?
        refresh_token
        auth.access_token = @connection.reload.access_token
      end

      auth
    end

    def google_api_available?
      defined?(Google::Apis::CalendarV3)
    end
  end
end
