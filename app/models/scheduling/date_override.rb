module Scheduling
  class DateOverride < ApplicationRecord
    belongs_to :member

    validates :date, presence: true, uniqueness: { scope: :member_id }
    validate :times_present_unless_unavailable
    validate :end_time_after_start_time

    scope :for_date, ->(date) { where(date: date) }
    scope :unavailable, -> { where(unavailable: true) }
    scope :available, -> { where(unavailable: false) }

    private

    def times_present_unless_unavailable
      if !unavailable && (start_time.blank? || end_time.blank?)
        errors.add(:base, 'start_time and end_time required when not marking as unavailable')
      end
    end

    def end_time_after_start_time
      if !unavailable && start_time.present? && end_time.present? && end_time <= start_time
        errors.add(:end_time, 'must be after start time')
      end
    end
  end
end
