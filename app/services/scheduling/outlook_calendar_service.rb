module Scheduling
  class OutlookCalendarService
    GRAPH_API_BASE = 'https://graph.microsoft.com/v1.0'

    def initialize(calendar_connection)
      @connection = calendar_connection
      @member = calendar_connection.member
    end

    def add_booking(booking)
      return unless @connection.add_bookings_to_calendar?

      event_data = {
        subject: "#{booking.event_type.title} - #{booking.client.full_name}",
        body: {
          contentType: 'Text',
          content: booking.notes || ''
        },
        start: {
          dateTime: booking.start_time.iso8601,
          timeZone: booking.timezone
        },
        end: {
          dateTime: booking.end_time.iso8601,
          timeZone: booking.timezone
        },
        attendees: [
          {
            emailAddress: {
              address: booking.client.email,
              name: booking.client.full_name
            },
            type: 'required'
          }
        ]
      }

      response = make_request(
        :post,
        '/me/calendar/events',
        event_data
      )

      if response&.dig('id')
        booking.update!(outlook_calendar_event_id: response['id'])
      end

      response
    rescue StandardError => e
      Rails.logger.error("Failed to add booking to Outlook Calendar: #{e.message}")
      nil
    end

    def update_booking(booking)
      return unless booking.outlook_calendar_event_id.present?

      event_data = {
        start: {
          dateTime: booking.start_time.iso8601,
          timeZone: booking.timezone
        },
        end: {
          dateTime: booking.end_time.iso8601,
          timeZone: booking.timezone
        }
      }

      make_request(
        :patch,
        "/me/calendar/events/#{booking.outlook_calendar_event_id}",
        event_data
      )
    rescue StandardError => e
      Rails.logger.error("Failed to update Outlook Calendar event: #{e.message}")
    end

    def delete_booking(booking)
      return unless booking.outlook_calendar_event_id.present?

      make_request(
        :delete,
        "/me/calendar/events/#{booking.outlook_calendar_event_id}"
      )
    rescue StandardError => e
      Rails.logger.error("Failed to delete Outlook Calendar event: #{e.message}")
    end

    def has_conflicts?(start_time, end_time)
      response = make_request(
        :get,
        '/me/calendar/calendarView',
        nil,
        {
          startDateTime: start_time.iso8601,
          endDateTime: end_time.iso8601
        }
      )

      return false unless response
      response.dig('value')&.any? || false
    rescue StandardError => e
      Rails.logger.error("Failed to check Outlook Calendar conflicts: #{e.message}")
      false
    end

    def refresh_token
      # Microsoft OAuth token refresh
      require 'net/http'
      require 'uri'
      require 'json'

      uri = URI.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token')
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(
        'client_id' => ENV['MICROSOFT_CLIENT_ID'],
        'client_secret' => ENV['MICROSOFT_CLIENT_SECRET'],
        'refresh_token' => @connection.refresh_token,
        'grant_type' => 'refresh_token',
        'scope' => 'Calendars.ReadWrite offline_access'
      )

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        @connection.update!(
          access_token: data['access_token'],
          refresh_token: data['refresh_token'] || @connection.refresh_token,
          token_expires_at: Time.current + data['expires_in'].to_i.seconds
        )
        true
      else
        Rails.logger.error("Failed to refresh Outlook token: #{response.body}")
        false
      end
    rescue StandardError => e
      Rails.logger.error("Failed to refresh Outlook Calendar token: #{e.message}")
      false
    end

    private

    def make_request(method, endpoint, body = nil, params = nil)
      require 'net/http'
      require 'uri'
      require 'json'

      # Refresh token if expired
      refresh_token if @connection.token_expired?

      uri = URI.parse("#{GRAPH_API_BASE}#{endpoint}")
      uri.query = URI.encode_www_form(params) if params

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = case method
                when :get
                  Net::HTTP::Get.new(uri)
                when :post
                  Net::HTTP::Post.new(uri)
                when :patch
                  Net::HTTP::Patch.new(uri)
                when :delete
                  Net::HTTP::Delete.new(uri)
                end

      request['Authorization'] = "Bearer #{@connection.access_token}"
      request['Content-Type'] = 'application/json' if body

      if body
        request.body = body.to_json
      end

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        response.body.present? ? JSON.parse(response.body) : {}
      else
        Rails.logger.error("Outlook API error: #{response.code} - #{response.body}")
        nil
      end
    end
  end
end
