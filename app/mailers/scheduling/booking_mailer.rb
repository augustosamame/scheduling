module Scheduling
  class BookingMailer < ApplicationMailer
    default from: -> { Scheduling.configuration.mailer_from || 'noreply@example.com' }

    # Booking confirmation email
    def confirmation_email(booking_id)
      @booking = Booking.find(booking_id)
      @client = @booking.client
      @member = @booking.member
      @event_type = @booking.event_type

      # Attach ICS calendar file
      attachments[@booking.ics_filename] = {
        mime_type: 'text/calendar',
        content: @booking.to_ics
      }

      I18n.with_locale(@booking.locale) do
        mail(
          to: @client.email,
          subject: t('scheduling.mailers.confirmation.subject', event_type: @event_type.title)
        )
      end
    end

    # Reminder email (sent before appointment)
    def reminder_email(booking_id)
      @booking = Booking.find(booking_id)
      @client = @booking.client
      @member = @booking.member
      @event_type = @booking.event_type

      # Attach ICS calendar file
      attachments[@booking.ics_filename] = {
        mime_type: 'text/calendar',
        content: @booking.to_ics
      }

      I18n.with_locale(@booking.locale) do
        mail(
          to: @client.email,
          subject: t('scheduling.mailers.reminder.subject', event_type: @event_type.title)
        )
      end
    end

    # Cancellation notification
    def cancellation_email(booking_id)
      @booking = Booking.find(booking_id)
      @client = @booking.client
      @member = @booking.member
      @event_type = @booking.event_type

      I18n.with_locale(@booking.locale) do
        mail(
          to: @client.email,
          subject: t('scheduling.mailers.cancellation.subject', event_type: @event_type.title)
        )
      end
    end

    # Reschedule notification
    def reschedule_email(booking_id)
      @booking = Booking.find(booking_id)
      @client = @booking.client
      @member = @booking.member
      @event_type = @booking.event_type

      I18n.with_locale(@booking.locale) do
        mail(
          to: @client.email,
          subject: t('scheduling.mailers.reschedule.subject', event_type: @event_type.title)
        )
      end
    end
  end
end
