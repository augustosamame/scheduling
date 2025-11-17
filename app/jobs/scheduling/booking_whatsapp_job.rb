module Scheduling
  class BookingWhatsappJob < ApplicationJob
    queue_as :default

    # Only retry on Twilio errors if Twilio is available
    retry_on StandardError, wait: :exponentially_longer, attempts: 3 if defined?(Twilio)

    def perform(booking_id, notification_type)
      # Skip if Twilio gem is not installed
      unless defined?(Twilio)
        Rails.logger.info "BookingWhatsappJob: Twilio gem not installed, skipping WhatsApp notification"
        return
      end

      # Skip if WhatsApp is not configured
      unless TwilioNotificationService.whatsapp_available?
        Rails.logger.info "BookingWhatsappJob: WhatsApp not configured, skipping WhatsApp notification"
        return
      end

      booking = Booking.find(booking_id)
      service = TwilioNotificationService.new(booking)

      case notification_type.to_sym
      when :confirmation
        service.send_whatsapp_confirmation
      when :cancellation
        service.send_whatsapp_cancellation
      when :reschedule
        service.send_whatsapp_reschedule
      when :reminder
        service.send_whatsapp_reminder
      else
        raise ArgumentError, "Unknown notification type: #{notification_type}"
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "BookingWhatsappJob: Booking ##{booking_id} not found: #{e.message}"
      # Don't retry if booking doesn't exist
    rescue TwilioNotificationService::TwilioNotConfiguredError => e
      Rails.logger.error "BookingWhatsappJob: Twilio not configured: #{e.message}"
      # Don't retry if Twilio is not configured
    rescue TwilioNotificationService::InvalidPhoneNumberError => e
      Rails.logger.error "BookingWhatsappJob: Invalid phone number for booking ##{booking_id}: #{e.message}"
      # Don't retry for invalid phone numbers
    rescue NameError => e
      # Handle case where TwilioNotificationService references Twilio constants
      Rails.logger.error "BookingWhatsappJob: Twilio dependencies not available: #{e.message}"
    end
  end
end
