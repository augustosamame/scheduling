module Scheduling
  module Admin
    class BookingsController < BaseController
      before_action :set_booking, only: [:show, :reschedule, :process_reschedule, :cancel, :send_reminder, :mark_as_paid]
      before_action :authorize_manage_booking, only: [:reschedule, :process_reschedule, :cancel, :send_reminder, :mark_as_paid]

      def index
        @bookings = scope_bookings
                    .includes(:client, :member, :event_type, :payment)
                    .order(start_time: :desc)

        # Apply filters
        @bookings = apply_filters(@bookings)

        # Apply pagination if Kaminari is available
        if @bookings.respond_to?(:page)
          @bookings = @bookings.page(params[:page]).per(20)
        else
          # Limit to 50 results if no pagination
          @bookings = @bookings.limit(50)
        end
      end

      def show
        authorize_manage_booking!(@booking)
        @booking_answers = @booking.booking_answers.includes(:booking_question)
      end

      def reschedule
        # Show reschedule form
        @available_dates = calculate_available_dates
      end

      def process_reschedule
        new_start_time = DateTime.parse(params[:new_start_time])

        # Admin can reschedule even if policy doesn't allow it
        new_booking = @booking.reschedule_to!(
          new_start_time,
          reason: params[:reason],
          initiated_by: "member",
          skip_policy_check: true
        )

        redirect_to admin_booking_path(new_booking), notice: t('scheduling.admin.bookings.reschedule.success')
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Reschedule validation error: #{e.record.errors.full_messages.join(', ')}"
        redirect_to reschedule_admin_booking_path(@booking), alert: "Validation error: #{e.record.errors.full_messages.join(', ')}"
      rescue StandardError => e
        Rails.logger.error "Reschedule error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        redirect_to reschedule_admin_booking_path(@booking), alert: "Error: #{e.message}"
      end

      def cancel
        if @booking.status == 'confirmed'
          @booking.cancel!(
            reason: params[:reason],
            initiated_by: "member"
          )

          redirect_to admin_booking_path(@booking), notice: "Booking cancelled successfully"
        else
          redirect_to admin_booking_path(@booking), alert: "Cannot cancel this booking"
        end
      rescue StandardError => e
        redirect_to admin_booking_path(@booking), alert: "Error cancelling booking: #{e.message}"
      end

      def send_reminder
        BookingReminderJob.perform_later(@booking.id)

        redirect_to admin_booking_path(@booking), notice: "Reminder email sent successfully"
      rescue StandardError => e
        redirect_to admin_booking_path(@booking), alert: "Error sending reminder: #{e.message}"
      end

      def mark_as_paid
        if @booking.event_type.requires_payment
          # Find or create payment record
          payment = @booking.payment || @booking.build_payment

          payment.assign_attributes(
            amount_cents: params[:amount_cents] || @booking.event_type.price_cents,
            amount_currency: params[:amount_currency] || @booking.event_type.price_currency,
            status: 'completed',
            payment_method: params[:payment_method] || 'manual',
            payment_provider: 'manual',
            external_transaction_id: params[:transaction_reference].presence,
            paid_at: Time.current,
            metadata: {
              marked_by_staff: true,
              staff_member_id: @current_member.id,
              notes: params[:payment_notes].presence
            }.compact
          )

          # Attach payment screenshot if provided
          if params[:payment_screenshot].present?
            payment.payment_screenshot.attach(params[:payment_screenshot])
          end

          payment.save!
          @booking.update!(payment_status: 'paid')

          redirect_to admin_booking_path(@booking), notice: "Booking marked as paid successfully"
        else
          redirect_to admin_booking_path(@booking), alert: "This booking does not require payment"
        end
      rescue StandardError => e
        redirect_to admin_booking_path(@booking), alert: "Error marking as paid: #{e.message}"
      end

      private

      def set_booking
        @booking = Booking.includes(:client, :member, :event_type, :payment).find(params[:id])
      end

      def authorize_manage_booking
        authorize_manage_booking!(@booking)
      end

      def apply_filters(bookings)
        bookings = bookings.where(status: params[:status]) if params[:status].present?
        bookings = bookings.where(payment_status: params[:payment_status]) if params[:payment_status].present?
        bookings = bookings.where(member_id: params[:member_id]) if params[:member_id].present?

        if params[:date_from].present?
          bookings = bookings.where('start_time >= ?', Date.parse(params[:date_from]).beginning_of_day)
        end

        if params[:date_to].present?
          bookings = bookings.where('start_time <= ?', Date.parse(params[:date_to]).end_of_day)
        end

        if params[:q].present?
          query = "%#{params[:q]}%"
          bookings = bookings.joins(:client).where(
            "scheduling_clients.first_name ILIKE ? OR scheduling_clients.last_name ILIKE ? OR scheduling_clients.email ILIKE ?",
            query, query, query
          )
        end

        bookings
      end

      def calculate_available_dates
        start_date = Date.current
        end_date = start_date + @booking.event_type.maximum_days_in_future.days
        timezone = @booking.member.team.location.timezone

        # Preload all data to avoid N+1 queries
        preloaded_data = preload_availability_data(start_date, end_date)

        # Get all slots for the entire range with preloaded data
        checker = AvailabilityChecker.new(
          @booking.member,
          @booking.event_type,
          preloaded_bookings: preloaded_data[:bookings],
          preloaded_date_overrides: preloaded_data[:date_overrides],
          preloaded_availabilities: preloaded_data[:availabilities],
          preloaded_calendar_connections: preloaded_data[:calendar_connections]
        )
        all_slots = checker.available_slots(start_date..end_date, timezone)

        # Group slots by date and return unique dates
        all_slots.map { |slot| slot[:start_time].to_date }.uniq.sort
      end

      def preload_availability_data(start_date, end_date)
        timezone = @booking.member.team.location.timezone
        start_time = start_date.in_time_zone(timezone).beginning_of_day
        end_time = end_date.in_time_zone(timezone).end_of_day

        # Preload all data and return as hash
        {
          date_overrides: @booking.member.date_overrides
            .where('date >= ? AND date <= ?', start_date, end_date)
            .to_a,
          availabilities: @booking.member.default_schedule&.availabilities&.to_a || [],
          bookings: @booking.member.bookings
            .where(status: 'confirmed')
            .where('start_time >= ? AND end_time <= ?', start_time, end_time)
            .to_a,
          calendar_connections: @booking.member.calendar_connections.to_a
        }
      end
    end
  end
end
