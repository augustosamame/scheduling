module Scheduling
  class BookingQuestion < ApplicationRecord
    belongs_to :event_type
    has_many :booking_answers, dependent: :destroy

    QUESTION_TYPES = %w[text textarea email phone url select radio checkbox number date].freeze

    validates :label, :question_type, presence: true
    validates :question_type, inclusion: { in: QUESTION_TYPES }
    validate :options_present_for_choice_types

    scope :ordered, -> { order(:position) }
    scope :required, -> { where(required: true) }

    def choice_type?
      %w[select radio checkbox].include?(question_type)
    end

    def options_array
      return [] unless options.present?
      JSON.parse(options)
    rescue JSON::ParserError
      []
    end

    private

    def options_present_for_choice_types
      if choice_type? && options_array.empty?
        errors.add(:options, 'must be provided for choice question types')
      end
    end
  end
end
