module Scheduling
  class BookingRescheduleJob < ApplicationJob
    queue_as :default

    def perform(old_booking_id, new_booking_id)
      old_booking = Scheduling::Booking.find(old_booking_id)
      new_booking = Scheduling::Booking.find(new_booking_id)

      # Check if email notifications are enabled
      return unless Scheduling.configuration.send_confirmation_emails

      # This is a placeholder - you'll need to implement the mailer
      # BookingMailer.reschedule(old_booking, new_booking).deliver_now

      Rails.logger.info("Booking reschedule email queued for booking ##{old_booking_id} -> ##{new_booking_id}")

      # TODO: Implement actual mailer
      # Example:
      # BookingMailer.with(old_booking: old_booking, new_booking: new_booking).reschedule_email.deliver_now
    rescue StandardError => e
      Rails.logger.error("Failed to send booking reschedule notification: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
