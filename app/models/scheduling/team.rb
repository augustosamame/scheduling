module Scheduling
  class Team < ApplicationRecord
    belongs_to :location
    has_one :organization, through: :location
    has_many :members, dependent: :destroy

    validates :name, :slug, presence: true
    validates :slug, uniqueness: { scope: :location_id }, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }

    before_validation :generate_slug, on: :create

    scope :active, -> { where(active: true) }

    def to_param
      slug
    end

    private

    def generate_slug
      self.slug ||= name.parameterize if name.present?
    end
  end
end
