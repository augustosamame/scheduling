module Scheduling
  class Member < ApplicationRecord
    belongs_to :team
    belongs_to :user
    has_one :location, through: :team
    has_one :organization, through: :location

    has_many :event_types, dependent: :destroy
    has_many :schedules, dependent: :destroy
    has_many :date_overrides, dependent: :destroy
    has_many :bookings, dependent: :destroy
    has_many :calendar_connections, dependent: :destroy

    # Delegate user attributes instead of duplicating them
    delegate :first_name, :last_name, :email, :title, :bio, to: :user, prefix: false, allow_nil: true

    validates :role, inclusion: { in: %w[admin manager member] }
    validates :booking_slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :user_id, uniqueness: { scope: :team_id }

    before_validation :generate_booking_slug, on: :create
    before_validation :sync_booking_slug_if_user_changed

    scope :active, -> { where(active: true) }
    scope :accepting_bookings, -> { where(accepts_bookings: true, active: true) }
    scope :admins, -> { where(role: 'admin') }
    scope :managers, -> { where(role: %w[admin manager]) }

    def admin?
      role == 'admin'
    end

    def manager?
      role.in?(%w[admin manager])
    end

    def default_schedule
      schedules.find_by(is_default: true) || schedules.first
    end

    def public_booking_url
      Rails.application.routes.url_helpers.scheduling_member_booking_url(
        organization_slug: organization.slug,
        booking_slug: booking_slug
      )
    end

    def to_param
      booking_slug
    end

    def full_name
      "#{first_name} #{last_name}".strip
    end

    private

    def generate_booking_slug
      if booking_slug.blank? && user.present?
        base_slug = [first_name, last_name].compact.join('-').parameterize
        self.booking_slug = base_slug

        counter = 1
        while Member.exists?(booking_slug: booking_slug)
          self.booking_slug = "#{base_slug}-#{counter}"
          counter += 1
        end
      end
    end

    def sync_booking_slug_if_user_changed
      # Regenerate booking_slug if user changed (optional - you might want to keep old slug)
      # Comment this out if you want booking_slug to be permanent
      # if user_id_changed? && user.present?
      #   generate_booking_slug
      # end
    end
  end
end
