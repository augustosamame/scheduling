module Scheduling
  class Client < ApplicationRecord
    belongs_to :organization
    has_many :bookings, dependent: :destroy

    validates :email, :first_name, :last_name, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :organization_id }
    validates :locale, inclusion: { in: %w[es en pt fr] }

    def full_name
      "#{first_name} #{last_name}"
    end

    def upcoming_bookings
      bookings.where('start_time > ?', Time.current).order(:start_time)
    end
  end
end
