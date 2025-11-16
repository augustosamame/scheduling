module Scheduling
  class BookingConfirmationJob < ApplicationJob
    queue_as :default

    def perform(booking_id)
      booking = Scheduling::Booking.find(booking_id)

      # Check if email notifications are enabled
      return unless Scheduling.configuration.send_confirmation_emails

      # Send confirmation email
      BookingMailer.confirmation_email(booking_id).deliver_now

      Rails.logger.info("Booking confirmation email sent for booking ##{booking_id}")
    rescue StandardError => e
      Rails.logger.error("Failed to send booking confirmation for ##{booking_id}: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
