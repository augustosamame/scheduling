module Scheduling
  class PublicBookingsController < ApplicationController
    before_action :set_locale
    before_action :find_member, only: [:index, :new, :create, :availability]
    before_action :find_event_type, only: [:new, :create]
    before_action :find_booking_by_token, only: [:show, :cancel, :process_cancellation, :reschedule, :process_reschedule]

    def index
      @event_types = @member.event_types.active
    end

    def new
      @booking = @event_type.bookings.build
      @booking_questions = @event_type.booking_questions.ordered
      @available_dates = calculate_available_dates
    end

    def create
      @client = find_or_create_client

      @booking = @event_type.bookings.build(booking_params)
      @booking.member = @member
      @booking.client = @client
      @booking.locale = I18n.locale.to_s

      # Build answers
      build_booking_answers if params[:answers].present?

      # Handle payment if required
      if @event_type.requires_payment && @event_type.payment_required_to_book
        payment_result = process_payment

        unless payment_result[:success]
          @booking.errors.add(:base, payment_result[:error])
          @booking_questions = @event_type.booking_questions.ordered
          render :new and return
        end
      end

      if @booking.save
        redirect_to scheduling_booking_confirmation_path(@booking.uid, locale: I18n.locale)
      else
        @booking_questions = @event_type.booking_questions.ordered
        @available_dates = calculate_available_dates
        render :new
      end
    end

    def show
      # Confirmation page
    end

    def cancel
      # Cancellation form
    end

    def process_cancellation
      if @booking.can_cancel?
        @booking.cancel!(
          reason: params[:reason],
          initiated_by: 'client'
        )
        flash[:notice] = t('scheduling.bookings.cancel.success')
        redirect_to root_path
      else
        flash[:alert] = t('scheduling.errors.past_cancellation_deadline',
                         hours: @booking.event_type.cancellation_policy_hours)
        render :cancel
      end
    end

    def reschedule
      @available_dates = calculate_available_dates
      @booking_questions = @booking.event_type.booking_questions.ordered
    end

    def process_reschedule
      new_start_time = DateTime.parse(params[:new_start_time])

      if @booking.can_reschedule?
        new_booking = @booking.reschedule_to!(
          new_start_time,
          reason: params[:reason],
          initiated_by: 'client'
        )
        flash[:notice] = t('scheduling.bookings.reschedule.success')
        redirect_to scheduling_booking_confirmation_path(new_booking.uid, locale: I18n.locale)
      else
        flash[:alert] = t('scheduling.errors.past_reschedule_deadline',
                         hours: @booking.event_type.rescheduling_policy_hours)
        @available_dates = calculate_available_dates
        render :reschedule
      end
    end

    def availability
      event_type = @member.event_types.find(params[:event_type_id])
      date = Date.parse(params[:date])
      timezone = params[:timezone] || 'America/Lima'

      checker = AvailabilityChecker.new(@member, event_type)
      @slots = checker.available_slots(date..date, timezone)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: @slots }
        format.html { render partial: 'time_slots', locals: { slots: @slots } }
      end
    end

    private

    def set_locale
      if Scheduling.configuration.detect_locale_from_browser
        browser_locale = extract_locale_from_accept_language_header
        I18n.locale = params[:locale] || browser_locale || Scheduling.configuration.default_locale
      else
        I18n.locale = params[:locale] || Scheduling.configuration.default_locale
      end
    end

    def extract_locale_from_accept_language_header
      return nil unless request.env['HTTP_ACCEPT_LANGUAGE']

      accepted = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
      Scheduling.configuration.available_locales.include?(accepted.to_sym) ? accepted : nil
    end

    def find_member
      @organization = Organization.find_by!(slug: params[:organization_slug])
      @member = @organization.members.find_by!(booking_slug: params[:booking_slug])
    end

    def find_event_type
      @event_type = @member.event_types.active.find_by!(slug: params[:event_slug])
    end

    def find_booking_by_token
      token = params[:token]
      @booking = Booking.find_by(cancellation_token: token) ||
                 Booking.find_by(reschedule_token: token)

      redirect_to root_path, alert: 'Booking not found' unless @booking
    end

    def find_or_create_client
      @organization.clients.find_or_create_by!(
        email: booking_params[:client_email]
      ) do |client|
        client.first_name = booking_params[:client_first_name]
        client.last_name = booking_params[:client_last_name]
        client.phone = booking_params[:client_phone]
        client.timezone = booking_params[:timezone] || 'America/Lima'
        client.locale = I18n.locale.to_s
      end
    end

    def booking_params
      params.require(:booking).permit(
        :start_time, :timezone, :notes,
        :client_first_name, :client_last_name, :client_email, :client_phone
      )
    end

    def build_booking_answers
      params[:answers].each do |question_id, answer|
        next if answer.blank?

        @booking.booking_answers.build(
          booking_question_id: question_id,
          answer: answer.is_a?(Array) ? answer.to_json : answer
        )
      end
    end

    def process_payment
      provider = params[:payment_provider] || 'stripe'

      case provider
      when 'stripe'
        StripePaymentService.new(@booking, params[:payment_method_id]).process
      when 'culqi'
        CulqiPaymentService.new(@booking, params[:token_id]).process
      else
        { success: false, error: 'Invalid payment provider' }
      end
    end

    def calculate_available_dates
      start_date = Date.current
      end_date = start_date + @event_type.maximum_days_in_future.days
      start_date..end_date
    end
  end
end
