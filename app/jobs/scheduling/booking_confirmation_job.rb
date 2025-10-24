module Scheduling
  class BookingConfirmationJob < ApplicationJob
    queue_as :default

    def perform(booking_id)
      booking = Scheduling::Booking.find(booking_id)

      # Check if email notifications are enabled
      return unless Scheduling.configuration.send_confirmation_emails

      # This is a placeholder - you'll need to implement the mailer
      # BookingMailer.confirmation(booking).deliver_now

      Rails.logger.info("Booking confirmation email queued for booking ##{booking_id}")

      # TODO: Implement actual mailer
      # Example:
      # BookingMailer.with(booking: booking).confirmation_email.deliver_now
    rescue StandardError => e
      Rails.logger.error("Failed to send booking confirmation for ##{booking_id}: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
