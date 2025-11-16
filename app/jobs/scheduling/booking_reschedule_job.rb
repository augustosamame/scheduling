module Scheduling
  class BookingRescheduleJob < ApplicationJob
    queue_as :default

    def perform(old_booking_id, new_booking_id)
      new_booking = Scheduling::Booking.find(new_booking_id)

      # Check if email notifications are enabled
      return unless Scheduling.configuration.send_confirmation_emails

      # Send reschedule email for the new booking
      BookingMailer.reschedule_email(new_booking_id).deliver_now

      Rails.logger.info("Booking reschedule email sent for booking ##{old_booking_id} -> ##{new_booking_id}")
    rescue StandardError => e
      Rails.logger.error("Failed to send booking reschedule notification for ##{new_booking_id}: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
