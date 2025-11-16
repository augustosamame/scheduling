module Scheduling
  class CalendarConnectionsController < ApplicationController
    before_action :find_member
    before_action :find_connection, only: [:destroy]

    # GET /scheduling/members/:member_id/calendar_connections
    def index
      @connections = @member.calendar_connections
      @google_connected = @connections.google.active.exists?
      @outlook_connected = @connections.outlook.active.exists?
    end

    # POST /scheduling/members/:member_id/calendar_connections/connect_google
    def connect_google
      redirect_to google_authorization_url, allow_other_host: true
    end

    # POST /scheduling/members/:member_id/calendar_connections/connect_outlook
    def connect_outlook
      redirect_to outlook_authorization_url, allow_other_host: true
    end

    # GET /scheduling/calendar_connections/google_callback
    def google_callback
      if params[:error]
        redirect_to member_calendar_connections_path(@member), alert: "Google authorization failed: #{params[:error]}"
        return
      end

      code = params[:code]
      state = params[:state]

      # Verify state to prevent CSRF
      member_id = verify_state_token(state)
      unless member_id
        redirect_to root_path, alert: "Invalid authorization request"
        return
      end

      @member = Member.find(member_id)

      # Exchange code for tokens
      tokens = exchange_google_code_for_tokens(code)

      if tokens
        # Create or update calendar connection
        connection = @member.calendar_connections.find_or_initialize_by(provider: 'google')
        connection.assign_attributes(
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token],
          token_expires_at: Time.current + tokens[:expires_in].seconds,
          active: true,
          add_bookings_to_calendar: true
        )

        if connection.save
          redirect_to member_calendar_connections_path(@member), notice: "Google Calendar connected successfully!"
        else
          redirect_to member_calendar_connections_path(@member), alert: "Failed to save calendar connection: #{connection.errors.full_messages.join(', ')}"
        end
      else
        redirect_to member_calendar_connections_path(@member), alert: "Failed to obtain Google Calendar access"
      end
    end

    # GET /scheduling/calendar_connections/outlook_callback
    def outlook_callback
      if params[:error]
        redirect_to member_calendar_connections_path(@member), alert: "Outlook authorization failed: #{params[:error]}"
        return
      end

      code = params[:code]
      state = params[:state]

      # Verify state to prevent CSRF
      member_id = verify_state_token(state)
      unless member_id
        redirect_to root_path, alert: "Invalid authorization request"
        return
      end

      @member = Member.find(member_id)

      # Exchange code for tokens
      tokens = exchange_outlook_code_for_tokens(code)

      if tokens
        # Create or update calendar connection
        connection = @member.calendar_connections.find_or_initialize_by(provider: 'outlook')
        connection.assign_attributes(
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token],
          token_expires_at: Time.current + tokens[:expires_in].seconds,
          active: true,
          add_bookings_to_calendar: true
        )

        if connection.save
          redirect_to member_calendar_connections_path(@member), notice: "Outlook Calendar connected successfully!"
        else
          redirect_to member_calendar_connections_path(@member), alert: "Failed to save calendar connection: #{connection.errors.full_messages.join(', ')}"
        end
      else
        redirect_to member_calendar_connections_path(@member), alert: "Failed to obtain Outlook Calendar access"
      end
    end

    # DELETE /scheduling/members/:member_id/calendar_connections/:id
    def destroy
      if @connection.destroy
        redirect_to member_calendar_connections_path(@member), notice: "Calendar disconnected successfully"
      else
        redirect_to member_calendar_connections_path(@member), alert: "Failed to disconnect calendar"
      end
    end

    private

    def find_member
      @member = Member.find(params[:member_id])
    end

    def find_connection
      @connection = @member.calendar_connections.find(params[:id])
    end

    def google_authorization_url
      require 'uri'
      require 'securerandom'

      state = generate_state_token(@member.id)

      params = {
        client_id: google_client_id,
        redirect_uri: google_callback_url,
        response_type: 'code',
        scope: 'https://www.googleapis.com/auth/calendar',
        access_type: 'offline',
        prompt: 'consent',
        state: state
      }

      "https://accounts.google.com/o/oauth2/v2/auth?#{URI.encode_www_form(params)}"
    end

    def outlook_authorization_url
      require 'uri'
      require 'securerandom'

      state = generate_state_token(@member.id)

      params = {
        client_id: outlook_client_id,
        redirect_uri: outlook_callback_url,
        response_type: 'code',
        scope: 'Calendars.ReadWrite offline_access',
        state: state
      }

      "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?#{URI.encode_www_form(params)}"
    end

    def exchange_google_code_for_tokens(code)
      require 'net/http'
      require 'uri'
      require 'json'

      uri = URI.parse('https://oauth2.googleapis.com/token')
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(
        'client_id' => google_client_id,
        'client_secret' => google_client_secret,
        'code' => code,
        'redirect_uri' => google_callback_url,
        'grant_type' => 'authorization_code'
      )

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        {
          access_token: data['access_token'],
          refresh_token: data['refresh_token'],
          expires_in: data['expires_in'].to_i
        }
      else
        Rails.logger.error("Google token exchange failed: #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Google token exchange error: #{e.message}")
      nil
    end

    def exchange_outlook_code_for_tokens(code)
      require 'net/http'
      require 'uri'
      require 'json'

      uri = URI.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token')
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(
        'client_id' => outlook_client_id,
        'client_secret' => outlook_client_secret,
        'code' => code,
        'redirect_uri' => outlook_callback_url,
        'grant_type' => 'authorization_code',
        'scope' => 'Calendars.ReadWrite offline_access'
      )

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        {
          access_token: data['access_token'],
          refresh_token: data['refresh_token'],
          expires_in: data['expires_in'].to_i
        }
      else
        Rails.logger.error("Outlook token exchange failed: #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Outlook token exchange error: #{e.message}")
      nil
    end

    def generate_state_token(member_id)
      # Store state in Rails cache with member_id
      require 'securerandom'
      state = SecureRandom.urlsafe_base64(32)
      Rails.cache.write("oauth_state_#{state}", member_id, expires_in: 10.minutes)
      state
    end

    def verify_state_token(state)
      return nil unless state.present?
      member_id = Rails.cache.read("oauth_state_#{state}")
      Rails.cache.delete("oauth_state_#{state}") if member_id
      member_id
    end

    # Configuration helpers
    def google_client_id
      ENV['GOOGLE_CALENDAR_CLIENT_ID'] || Scheduling.configuration.google_client_id
    end

    def google_client_secret
      ENV['GOOGLE_CALENDAR_CLIENT_SECRET'] || Scheduling.configuration.google_client_secret
    end

    def google_callback_url
      main_app.scheduling_google_callback_url rescue "#{request.base_url}/scheduling/calendar_connections/google_callback"
    end

    def outlook_client_id
      ENV['MICROSOFT_CLIENT_ID'] || Scheduling.configuration.microsoft_client_id
    end

    def outlook_client_secret
      ENV['MICROSOFT_CLIENT_SECRET'] || Scheduling.configuration.microsoft_client_secret
    end

    def outlook_callback_url
      main_app.scheduling_outlook_callback_url rescue "#{request.base_url}/scheduling/calendar_connections/outlook_callback"
    end
  end
end
