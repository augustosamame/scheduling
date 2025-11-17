module Scheduling
  class TwilioNotificationService
    class TwilioNotConfiguredError < StandardError; end
    class InvalidPhoneNumberError < StandardError; end

    def initialize(booking)
      @booking = booking
      @client = booking.client
      @member = booking.member
      @event_type = booking.event_type
      @config = Scheduling.configuration
    end

    # Send SMS confirmation
    def send_sms_confirmation
      return unless sms_enabled?
      return unless @client.phone.present?

      send_sms(
        to: @client.phone,
        body: confirmation_message
      )
    end

    # Send WhatsApp confirmation
    def send_whatsapp_confirmation
      return unless whatsapp_enabled?
      return unless @client.phone.present?

      send_whatsapp(
        to: @client.phone,
        body: confirmation_message_whatsapp
      )
    end

    # Send SMS cancellation
    def send_sms_cancellation
      return unless sms_enabled?
      return unless @client.phone.present?

      send_sms(
        to: @client.phone,
        body: cancellation_message
      )
    end

    # Send WhatsApp cancellation
    def send_whatsapp_cancellation
      return unless whatsapp_enabled?
      return unless @client.phone.present?

      send_whatsapp(
        to: @client.phone,
        body: cancellation_message
      )
    end

    # Send SMS reschedule notification
    def send_sms_reschedule
      return unless sms_enabled?
      return unless @client.phone.present?

      send_sms(
        to: @client.phone,
        body: reschedule_message
      )
    end

    # Send WhatsApp reschedule notification
    def send_whatsapp_reschedule
      return unless whatsapp_enabled?
      return unless @client.phone.present?

      send_whatsapp(
        to: @client.phone,
        body: reschedule_message
      )
    end

    # Send SMS reminder
    def send_sms_reminder
      return unless sms_enabled?
      return unless @client.phone.present?

      send_sms(
        to: @client.phone,
        body: reminder_message
      )
    end

    # Send WhatsApp reminder
    def send_whatsapp_reminder
      return unless whatsapp_enabled?
      return unless @client.phone.present?

      send_whatsapp(
        to: @client.phone,
        body: reminder_message_whatsapp
      )
    end

    # Class method to check if Twilio is configured
    def self.configured?
      twilio_available?
    end

    # Check if SMS is enabled and configured
    def self.sms_available?
      Scheduling.configuration.enable_sms_notifications && twilio_available?
    end

    # Check if WhatsApp is enabled and configured
    def self.whatsapp_available?
      Scheduling.configuration.enable_whatsapp_notifications && twilio_available?
    end

    private

    def sms_enabled?
      @config.enable_sms_notifications && self.class.twilio_available?
    end

    def whatsapp_enabled?
      @config.enable_whatsapp_notifications && self.class.twilio_available?
    end

    def self.twilio_available?
      return false unless defined?(Twilio)

      account_sid = ENV['TWILIO_ACCOUNT_SID'] || Scheduling.configuration.twilio_account_sid
      auth_token = ENV['TWILIO_AUTH_TOKEN'] || Scheduling.configuration.twilio_auth_token

      account_sid.present? && auth_token.present?
    end

    def twilio_client
      @twilio_client ||= begin
        raise TwilioNotConfiguredError, "Twilio is not configured" unless self.class.twilio_available?

        account_sid = ENV['TWILIO_ACCOUNT_SID'] || @config.twilio_account_sid
        auth_token = ENV['TWILIO_AUTH_TOKEN'] || @config.twilio_auth_token

        Twilio::REST::Client.new(account_sid, auth_token)
      end
    end

    def send_sms(to:, body:)
      validate_phone_number!(to)

      from_number = ENV['TWILIO_PHONE_NUMBER'] || @config.twilio_phone_number
      raise TwilioNotConfiguredError, "Twilio phone number not configured" unless from_number.present?

      twilio_client.messages.create(
        from: from_number,
        to: normalize_phone_number(to),
        body: body
      )

      Rails.logger.info "SMS sent to #{to} for booking ##{@booking.id}"
    rescue Twilio::REST::RestError => e
      Rails.logger.error "Twilio SMS error for booking ##{@booking.id}: #{e.message}"
      raise
    end

    def send_whatsapp(to:, body:)
      validate_phone_number!(to)

      from_number = ENV['TWILIO_WHATSAPP_NUMBER'] || @config.twilio_whatsapp_number
      raise TwilioNotConfiguredError, "Twilio WhatsApp number not configured" unless from_number.present?

      # WhatsApp numbers must be prefixed with 'whatsapp:'
      from_whatsapp = from_number.start_with?('whatsapp:') ? from_number : "whatsapp:#{from_number}"
      to_whatsapp = normalize_phone_number(to)
      to_whatsapp = to_whatsapp.start_with?('whatsapp:') ? to_whatsapp : "whatsapp:#{to_whatsapp}"

      twilio_client.messages.create(
        from: from_whatsapp,
        to: to_whatsapp,
        body: body
      )

      Rails.logger.info "WhatsApp sent to #{to} for booking ##{@booking.id}"
    rescue Twilio::REST::RestError => e
      Rails.logger.error "Twilio WhatsApp error for booking ##{@booking.id}: #{e.message}"
      raise
    end

    def validate_phone_number!(phone)
      return if phone.blank?

      # Remove whatsapp: prefix if present
      clean_phone = phone.gsub(/^whatsapp:/, '')

      # Basic validation - should start with + and have at least 10 digits
      unless clean_phone.match?(/^\+?\d{10,15}$/)
        raise InvalidPhoneNumberError, "Invalid phone number format: #{phone}"
      end
    end

    def normalize_phone_number(phone)
      # Remove any non-digit characters except +
      clean = phone.gsub(/[^\d+]/, '')

      # Ensure it starts with +
      clean.start_with?('+') ? clean : "+#{clean}"
    end

    # Message templates
    def confirmation_message
      I18n.with_locale(@booking.locale) do
        date_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%A, %B %d, %Y')
        time_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%I:%M %p')

        I18n.t('scheduling.notifications.sms.confirmation',
          client_name: @client.first_name,
          member_name: @member.full_name,
          event_type: @event_type.title,
          date: date_str,
          time: time_str,
          location: location_details,
          cancel_url: cancel_url
        )
      end
    rescue I18n::MissingTranslationData
      # Fallback message if translation is missing
      "Your appointment with #{@member.full_name} for #{@event_type.title} is confirmed for #{@booking.start_time.strftime('%b %d at %I:%M %p')}. #{location_details}"
    end

    def confirmation_message_whatsapp
      I18n.with_locale(@booking.locale) do
        date_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%A, %B %d, %Y')
        time_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%I:%M %p')

        # WhatsApp supports rich formatting
        "*Booking Confirmed* ✅\n\n" \
        "Hello #{@client.first_name}! Your appointment has been confirmed.\n\n" \
        "*Professional:* #{@member.full_name}\n" \
        "*Service:* #{@event_type.title}\n" \
        "*Date:* #{date_str}\n" \
        "*Time:* #{time_str}\n" \
        "*Location:* #{location_details}\n\n" \
        "Need to cancel? #{cancel_url}"
      end
    end

    def cancellation_message
      I18n.with_locale(@booking.locale) do
        I18n.t('scheduling.notifications.sms.cancellation',
          client_name: @client.first_name,
          member_name: @member.full_name,
          event_type: @event_type.title
        )
      end
    rescue I18n::MissingTranslationData
      "Your appointment with #{@member.full_name} for #{@event_type.title} has been cancelled."
    end

    def reschedule_message
      I18n.with_locale(@booking.locale) do
        date_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%A, %B %d, %Y')
        time_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%I:%M %p')

        I18n.t('scheduling.notifications.sms.reschedule',
          client_name: @client.first_name,
          member_name: @member.full_name,
          date: date_str,
          time: time_str
        )
      end
    rescue I18n::MissingTranslationData
      "Your appointment with #{@member.full_name} has been rescheduled to #{@booking.start_time.strftime('%b %d at %I:%M %p')}."
    end

    def reminder_message
      I18n.with_locale(@booking.locale) do
        date_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%A, %B %d, %Y')
        time_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%I:%M %p')

        I18n.t('scheduling.notifications.sms.reminder',
          client_name: @client.first_name,
          member_name: @member.full_name,
          event_type: @event_type.title,
          date: date_str,
          time: time_str,
          location: location_details
        )
      end
    rescue I18n::MissingTranslationData
      "Reminder: Your appointment with #{@member.full_name} for #{@event_type.title} is tomorrow at #{@booking.start_time.strftime('%I:%M %p')}. #{location_details}"
    end

    def reminder_message_whatsapp
      I18n.with_locale(@booking.locale) do
        date_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%A, %B %d, %Y')
        time_str = @booking.start_time.in_time_zone(@booking.timezone).strftime('%I:%M %p')

        "*Appointment Reminder* ⏰\n\n" \
        "Hello #{@client.first_name}! This is a reminder about your upcoming appointment.\n\n" \
        "*Professional:* #{@member.full_name}\n" \
        "*Service:* #{@event_type.title}\n" \
        "*Date:* #{date_str}\n" \
        "*Time:* #{time_str}\n" \
        "*Location:* #{location_details}\n\n" \
        "See you soon!"
      end
    end

    def location_details
      if @event_type.location_type == 'video'
        'Video call'
      elsif @event_type.location_type == 'phone'
        'Phone call'
      elsif @event_type.location_details.present?
        @event_type.location_details
      else
        @member.team.location.name
      end
    end

    def cancel_url
      "#{app_url}/bookings/#{@booking.cancellation_token}/cancel"
    end

    def app_url
      ENV['APP_URL'] || 'http://localhost:3000'
    end
  end
end
