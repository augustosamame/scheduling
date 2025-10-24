module Scheduling
  class EventType < ApplicationRecord
    belongs_to :member
    has_many :booking_questions, dependent: :destroy
    has_many :bookings, dependent: :destroy

    monetize :price_cents, with_currency: :price_currency if defined?(MoneyRails)

    validates :title, :slug, :duration_minutes, presence: true
    validates :slug, uniqueness: { scope: :member_id }, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :duration_minutes, numericality: { greater_than: 0 }
    validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :location_type, inclusion: { in: %w[in_person phone video] }
    validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }

    accepts_nested_attributes_for :booking_questions, allow_destroy: true

    before_validation :generate_slug, on: :create

    scope :active, -> { where(active: true) }
    scope :requiring_payment, -> { where(requires_payment: true) }

    def free?
      !requires_payment || price_cents.zero?
    end

    def payment_optional?
      requires_payment && !payment_required_to_book
    end

    def allows_cancellation_until
      return nil unless allow_cancellation
      cancellation_policy_hours.hours
    end

    def allows_rescheduling_until
      return nil unless allow_rescheduling
      rescheduling_policy_hours.hours
    end

    def public_booking_url
      Rails.application.routes.url_helpers.scheduling_public_booking_url(
        organization_slug: member.organization.slug,
        booking_slug: member.booking_slug,
        event_slug: slug
      )
    end

    def to_param
      slug
    end

    private

    def generate_slug
      self.slug ||= title.parameterize if title.present?
    end
  end
end
