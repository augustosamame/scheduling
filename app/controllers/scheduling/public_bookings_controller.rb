module Scheduling
  class PublicBookingsController < ApplicationController
    before_action :set_locale
    before_action :find_organization_only, only: [ :organization_index ]
    before_action :find_member, only: [ :index, :new, :create, :availability ]
    before_action :find_event_type, only: [ :new, :create, :availability ]
    before_action :find_booking_by_uid, only: [ :show, :download_calendar ]
    before_action :find_booking_by_token, only: [ :cancel, :process_cancellation, :reschedule, :process_reschedule ]

    def organization_index
      # Show all bookable members in the organization
      @members = @organization.members
        .joins(:event_types)
        .where(active: true, accepts_bookings: true)
        .where(scheduling_event_types: { active: true })
        .includes(:event_types, :team, user: [])
        .distinct
    end

    def index
      @event_types = @member.event_types.active
    end

    def new
      @booking = @event_type.bookings.build
      @booking_questions = @event_type.booking_questions.ordered

      # Eager load associations to prevent N+1 queries
      preload_availability_associations

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
        redirect_to booking_confirmation_path(@booking.uid, locale: I18n.locale)
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
          initiated_by: "client"
        )
        flash[:notice] = t("scheduling.bookings.cancel.success")
        redirect_to root_path
      else
        flash[:alert] = t("scheduling.errors.past_cancellation_deadline",
                         hours: @booking.event_type.cancellation_policy_hours)
        render :cancel
      end
    end

    def reschedule
      @organization = @member.team.location.organization

      # Eager load associations to prevent N+1 queries
      preload_availability_associations

      @available_dates = calculate_available_dates
      @booking_questions = @booking.event_type.booking_questions.ordered
    end

    def process_reschedule
      new_start_time = DateTime.parse(params[:new_start_time])

      if @booking.can_reschedule?
        new_booking = @booking.reschedule_to!(
          new_start_time,
          reason: params[:reason],
          initiated_by: "client"
        )
        flash[:notice] = t("scheduling.bookings.reschedule.success")
        redirect_to booking_confirmation_path(new_booking.uid, locale: I18n.locale)
      else
        flash[:alert] = t("scheduling.errors.past_reschedule_deadline",
                         hours: @booking.event_type.rescheduling_policy_hours)
        @available_dates = calculate_available_dates
        render :reschedule
      end
    end

    def availability
      date = Date.parse(params[:date])
      timezone = params[:timezone] || @member.team.location.timezone

      # Preload bookings for this specific date to avoid N+1
      start_time = date.in_time_zone(timezone).beginning_of_day
      end_time = date.in_time_zone(timezone).end_of_day
      preloaded_bookings = @member.bookings
        .confirmed
        .where('start_time < ? AND end_time > ?', end_time, start_time)
        .to_a

      # Preload calendar connections
      @member.calendar_connections.to_a

      checker = AvailabilityChecker.new(@member, @event_type, preloaded_bookings: preloaded_bookings)
      slots = checker.available_slots(date..date, timezone)

      render json: slots
    end

    # Download ICS file for adding to calendar
    def download_calendar
      send_data @booking.to_ics,
                filename: @booking.ics_filename,
                type: 'text/calendar',
                disposition: 'attachment'
    end

    private

    def set_locale
      # Priority order:
      # 1. URL parameter (?locale=xx) - saves to session
      # 2. Session stored locale
      # 3. Browser detected locale (if enabled)
      # 4. Default locale from configuration

      if params[:locale].present?
        # User explicitly selected a locale via URL parameter
        locale = params[:locale].to_sym
        if Scheduling.configuration.available_locales.include?(locale)
          session[:locale] = locale
          I18n.locale = locale
        else
          I18n.locale = Scheduling.configuration.default_locale
        end
      elsif session[:locale].present?
        # Use previously stored locale from session
        I18n.locale = session[:locale]
      elsif Scheduling.configuration.detect_locale_from_browser
        # Detect from browser and save to session
        browser_locale = extract_locale_from_accept_language_header
        locale = browser_locale&.to_sym || Scheduling.configuration.default_locale
        session[:locale] = locale
        I18n.locale = locale
      else
        # Use default locale and save to session
        session[:locale] = Scheduling.configuration.default_locale
        I18n.locale = Scheduling.configuration.default_locale
      end
    end

    def extract_locale_from_accept_language_header
      return nil unless request.env["HTTP_ACCEPT_LANGUAGE"]

      accepted = request.env["HTTP_ACCEPT_LANGUAGE"].scan(/^[a-z]{2}/).first
      Scheduling.configuration.available_locales.include?(accepted.to_sym) ? accepted : nil
    end

    def find_organization_only
      @organization = Organization.find_by!(slug: params[:organization_slug])
    end

    def find_member
      @organization = Organization.find_by!(slug: params[:organization_slug])
      @member = @organization.members.find_by!(booking_slug: params[:booking_slug])
    end

    def find_event_type
      @event_type = @member.event_types.active.find_by!(slug: params[:event_slug])
    end

    def find_booking_by_uid
      @booking = Booking.find_by!(uid: params[:uid])
      @member = @booking.member
      @event_type = @booking.event_type
      @organization = @member.organization
    end

    def find_booking_by_token
      token = params[:token]
      @booking = Booking.find_by(cancellation_token: token) ||
                 Booking.find_by(reschedule_token: token)

      if @booking
        @member = @booking.member
        @event_type = @booking.event_type
        @organization = @member.organization
      else
        redirect_to root_path, alert: "Booking not found"
      end
    end

    def find_or_create_client
      @organization.clients.find_or_create_by!(
        email: client_params[:client_email]
      ) do |client|
        client.first_name = client_params[:client_first_name]
        client.last_name = client_params[:client_last_name]
        client.phone = client_params[:client_phone]
        client.timezone = client_params[:timezone] || "America/Lima"
        client.locale = I18n.locale.to_s
      end
    end

    def booking_params
      params.require(:booking).permit(
        :start_time, :timezone, :notes
      )
    end

    def client_params
      params.require(:booking).permit(
        :client_first_name, :client_last_name, :client_email, :client_phone, :timezone
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
      provider = params[:payment_provider] || "stripe"

      case provider
      when "stripe"
        StripePaymentService.new(@booking, params[:payment_method_id]).process
      when "culqi"
        CulqiPaymentService.new(@booking, params[:token_id]).process
      else
        { success: false, error: "Invalid payment provider" }
      end
    end

    def preload_availability_associations
      # Preload calendar connections to avoid N+1
      @member.calendar_connections.to_a

      # Preload default schedule and availabilities
      if @member.default_schedule
        @member.default_schedule.availabilities.to_a
      end

      # Bulk load all confirmed bookings in the date range
      start_date = Date.current
      end_date = start_date + @event_type.maximum_days_in_future.days
      timezone = @member.team.location.timezone
      start_time = start_date.in_time_zone(timezone).beginning_of_day
      end_time = end_date.in_time_zone(timezone).end_of_day

      @preloaded_bookings = @member.bookings
        .where(status: 'confirmed')
        .where('start_time < ? AND end_time > ?', end_time, start_time)
        .to_a
    end

    def calculate_available_dates
      start_date = Date.current
      end_date = start_date + @event_type.maximum_days_in_future.days

      # Get actual dates that have available time slots
      # Pass preloaded bookings to avoid N+1 queries
      checker = AvailabilityChecker.new(@member, @event_type, preloaded_bookings: @preloaded_bookings)
      available_dates = []

      (start_date..end_date).each do |date|
        slots = checker.available_slots(date..date, @member.team.location.timezone)
        available_dates << date if slots.any?
      end

      available_dates
    end
  end
end
