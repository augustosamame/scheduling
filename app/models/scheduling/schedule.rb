module Scheduling
  class Schedule < ApplicationRecord
    belongs_to :member
    has_many :availabilities, dependent: :destroy

    validates :name, :timezone, presence: true
    validate :only_one_default_per_member

    accepts_nested_attributes_for :availabilities, allow_destroy: true

    scope :default, -> { where(is_default: true) }

    private

    def only_one_default_per_member
      if is_default && member.schedules.where(is_default: true).where.not(id: id).exists?
        errors.add(:is_default, 'can only have one default schedule per member')
      end
    end
  end
end
