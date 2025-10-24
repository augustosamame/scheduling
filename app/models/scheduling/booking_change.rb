module Scheduling
  class BookingChange < ApplicationRecord
    belongs_to :booking

    CHANGE_TYPES = %w[cancelled rescheduled completed no_show].freeze

    validates :change_type, inclusion: { in: CHANGE_TYPES }
    validates :initiated_by, inclusion: { in: %w[client member system] }

    scope :recent, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(change_type: type) }
  end
end
