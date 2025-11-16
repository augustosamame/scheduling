module Scheduling
  class BookingReminderJob < ApplicationJob
    queue_as :default

    def perform(booking_id)
      booking = Scheduling::Booking.find(booking_id)

      # Check if reminder emails are enabled
      return unless Scheduling.configuration.send_reminder_emails

      # Send reminder email
      BookingMailer.reminder_email(booking_id).deliver_now

      Rails.logger.info("Booking reminder email sent for booking ##{booking_id}")
    rescue StandardError => e
      Rails.logger.error("Failed to send booking reminder for ##{booking_id}: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
