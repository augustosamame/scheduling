module Scheduling
  class BookingAnswer < ApplicationRecord
    belongs_to :booking
    belongs_to :booking_question

    validates :answer, presence: true, if: -> { booking_question.required? }
  end
end
