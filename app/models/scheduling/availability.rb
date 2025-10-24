module Scheduling
  class Availability < ApplicationRecord
    belongs_to :schedule

    validates :day_of_week, :start_time, :end_time, presence: true
    validates :day_of_week, inclusion: { in: 0..6 }
    validate :end_time_after_start_time

    scope :for_day, ->(day) { where(day_of_week: day) }
    scope :ordered, -> { order(:day_of_week, :start_time) }

    DAYS = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

    def day_name
      DAYS[day_of_week]
    end

    private

    def end_time_after_start_time
      if start_time.present? && end_time.present? && end_time <= start_time
        errors.add(:end_time, 'must be after start time')
      end
    end
  end
end
