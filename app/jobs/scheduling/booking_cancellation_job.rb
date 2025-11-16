module Scheduling
  class BookingCancellationJob < ApplicationJob
    queue_as :default

    def perform(booking_id)
      booking = Scheduling::Booking.find(booking_id)

      # Check if email notifications are enabled
      return unless Scheduling.configuration.send_confirmation_emails

      # Send cancellation email
      BookingMailer.cancellation_email(booking_id).deliver_now

      Rails.logger.info("Booking cancellation email sent for booking ##{booking_id}")
    rescue StandardError => e
      Rails.logger.error("Failed to send booking cancellation for ##{booking_id}: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
