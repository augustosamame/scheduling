module Scheduling
  class Booking < ApplicationRecord
    belongs_to :event_type
    belongs_to :member
    belongs_to :client
    belongs_to :rescheduled_from, class_name: 'Booking', optional: true

    has_many :booking_answers, dependent: :destroy
    has_many :booking_questions, through: :booking_answers
    has_one :payment, dependent: :destroy
    has_many :booking_changes, dependent: :destroy

    STATUSES = %w[confirmed cancelled rescheduled completed no_show].freeze
    PAYMENT_STATUSES = %w[not_required pending paid failed refunded].freeze

    validates :status, inclusion: { in: STATUSES }
    validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
    validates :start_time, :end_time, :timezone, presence: true
    validate :within_available_hours
    validate :no_conflicts
    validate :meets_minimum_notice
    validate :within_maximum_days
    validate :payment_completed_if_required
    validate :all_required_questions_answered

    before_validation :set_end_time, on: :create
    before_create :generate_tokens
    before_create :set_payment_status
    after_create :send_confirmation_email, if: -> { status == 'confirmed' }
    after_create :add_to_external_calendar, if: -> { status == 'confirmed' }

    scope :upcoming, -> { where('start_time > ?', Time.current) }
    scope :past, -> { where('start_time <= ?', Time.current) }
    scope :confirmed, -> { where(status: 'confirmed') }
    scope :requires_payment, -> { where(payment_status: 'pending') }
    scope :for_date, ->(date) { where('DATE(start_time) = ?', date) }

    accepts_nested_attributes_for :booking_answers

    def duration_minutes
      ((end_time - start_time) / 60).to_i
    end

    def can_cancel?
      return false unless status == 'confirmed'
      return false unless event_type.allow_cancellation

      policy_hours = event_type.cancellation_policy_hours
      return true if policy_hours.zero?

      start_time > (Time.current + policy_hours.hours)
    end

    def can_reschedule?
      return false unless status == 'confirmed'
      return false unless event_type.allow_rescheduling

      policy_hours = event_type.rescheduling_policy_hours
      return true if policy_hours.zero?

      start_time > (Time.current + policy_hours.hours)
    end

    def cancel!(reason: nil, initiated_by: 'client')
      raise 'Cannot cancel this booking' unless can_cancel?

      transaction do
        booking_changes.create!(
          change_type: 'cancelled',
          old_start_time: start_time,
          old_end_time: end_time,
          reason: reason,
          initiated_by: initiated_by
        )

        update!(
          status: 'cancelled',
          cancellation_reason: reason
        )

        process_refund if payment&.completed?
        send_cancellation_email
        remove_from_external_calendar
      end
    end

    def reschedule_to!(new_start_time, reason: nil, initiated_by: 'client')
      raise 'Cannot reschedule this booking' unless can_reschedule?

      new_end_time = new_start_time + event_type.duration_minutes.minutes

      transaction do
        booking_changes.create!(
          change_type: 'rescheduled',
          old_start_time: start_time,
          old_end_time: end_time,
          new_start_time: new_start_time,
          new_end_time: new_end_time,
          reason: reason,
          initiated_by: initiated_by
        )

        # Create new booking
        new_booking = dup
        new_booking.assign_attributes(
          start_time: new_start_time,
          end_time: new_end_time,
          rescheduled_from_id: id,
          status: 'confirmed',
          payment_status: payment_status
        )

        # Transfer payment if exists
        if payment&.completed?
          new_booking.build_payment(
            amount_cents: payment.amount_cents,
            amount_currency: payment.amount_currency,
            status: 'completed',
            payment_method: payment.payment_method,
            payment_provider: payment.payment_provider,
            paid_at: payment.paid_at
          )
        end

        # Copy answers
        booking_answers.each do |answer|
          new_booking.booking_answers.build(
            booking_question_id: answer.booking_question_id,
            answer: answer.answer
          )
        end

        new_booking.save!

        # Mark old booking as rescheduled
        update!(status: 'rescheduled')

        send_reschedule_email(new_booking)
        update_external_calendar(new_booking)

        new_booking
      end
    end

    def answer_for(question)
      booking_answers.find_by(booking_question: question)&.answer
    end

    def public_cancellation_url
      Rails.application.routes.url_helpers.scheduling_cancel_booking_url(
        token: cancellation_token,
        locale: locale
      )
    end

    def public_reschedule_url
      Rails.application.routes.url_helpers.scheduling_reschedule_booking_url(
        token: reschedule_token,
        locale: locale
      )
    end

    private

    def set_end_time
      self.end_time ||= start_time + event_type.duration_minutes.minutes if start_time && event_type
    end

    def generate_tokens
      self.uid ||= SecureRandom.uuid
      self.reschedule_token ||= SecureRandom.urlsafe_base64(32)
      self.cancellation_token ||= SecureRandom.urlsafe_base64(32)
    end

    def set_payment_status
      if event_type.requires_payment && event_type.payment_required_to_book
        self.payment_status = 'pending'
      else
        self.payment_status = 'not_required'
      end
    end

    def within_available_hours
      checker = AvailabilityChecker.new(member, event_type)
      unless checker.available_at?(start_time, duration_minutes)
        errors.add(:start_time, 'is not within available hours')
      end
    end

    def no_conflicts
      conflicting = member.bookings
                         .confirmed
                         .where.not(id: id)
                         .where('start_time < ? AND end_time > ?', end_time, start_time)

      if conflicting.exists?
        errors.add(:start_time, 'conflicts with another booking')
      end
    end

    def meets_minimum_notice
      required_notice = event_type.minimum_notice_hours.hours
      if start_time < (Time.current + required_notice)
        errors.add(:start_time, "requires at least #{event_type.minimum_notice_hours} hours notice")
      end
    end

    def within_maximum_days
      max_days = event_type.maximum_days_in_future
      if start_time > (Time.current + max_days.days)
        errors.add(:start_time, "cannot book more than #{max_days} days in advance")
      end
    end

    def payment_completed_if_required
      if event_type.requires_payment && event_type.payment_required_to_book
        unless payment_status == 'paid'
          errors.add(:payment_status, 'must be completed before booking')
        end
      end
    end

    def all_required_questions_answered
      required_questions = event_type.booking_questions.where(required: true)
      answered_question_ids = booking_answers.map(&:booking_question_id)

      required_questions.each do |question|
        unless answered_question_ids.include?(question.id)
          errors.add(:base, "#{question.label} is required")
        end
      end
    end

    def process_refund
      PaymentRefundJob.perform_later(payment.id)
    end

    def send_confirmation_email
      BookingConfirmationJob.perform_later(id)
    end

    def send_cancellation_email
      BookingCancellationJob.perform_later(id)
    end

    def send_reschedule_email(new_booking)
      BookingRescheduleJob.perform_later(id, new_booking.id)
    end

    def add_to_external_calendar
      CalendarSyncJob.perform_later(id, 'create')
    end

    def remove_from_external_calendar
      CalendarSyncJob.perform_later(id, 'delete')
    end

    def update_external_calendar(new_booking)
      CalendarSyncJob.perform_later(id, 'update', new_booking.id)
    end
  end
end
