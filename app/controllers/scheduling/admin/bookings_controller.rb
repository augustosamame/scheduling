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

        if @booking.can_reschedule?
          new_booking = @booking.reschedule_to!(
            new_start_time,
            reason: params[:reason],
            initiated_by: "staff"
          )

          redirect_to admin_booking_path(new_booking), notice: "Booking rescheduled successfully"
        else
          redirect_to admin_booking_path(@booking), alert: "Cannot reschedule this booking"
        end
      rescue StandardError => e
        redirect_to admin_booking_path(@booking), alert: "Error rescheduling booking: #{e.message}"
      end

      def cancel
        if @booking.status == 'confirmed'
          @booking.cancel!(
            reason: params[:reason],
            initiated_by: "staff"
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

          # Handle payment screenshot upload
          if params[:payment_screenshot].present?
            # Store screenshot information in metadata
            # In production, you'd upload to S3 or similar
            payment.metadata = (payment.metadata || {}).merge(
              screenshot_uploaded: true,
              screenshot_filename: params[:payment_screenshot].original_filename
            )
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

        checker = AvailabilityChecker.new(@booking.member, @booking.event_type)
        available_dates = []

        (start_date..end_date).each do |date|
          slots = checker.available_slots(date..date, @booking.member.team.location.timezone)
          available_dates << date if slots.any?
        end

        available_dates
      end
    end
  end
end
