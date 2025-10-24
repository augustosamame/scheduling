module Scheduling
  class Location < ApplicationRecord
    belongs_to :organization
    has_many :teams, dependent: :destroy
    has_many :members, through: :teams

    validates :name, :slug, :timezone, presence: true
    validates :slug, uniqueness: { scope: :organization_id }, format: { with: /\A[a-z0-9\-]+\z/ }

    before_validation :generate_slug, on: :create

    scope :active, -> { where(active: true) }

    def full_address
      [address, city, state, postal_code, country].compact.join(', ')
    end

    def to_param
      slug
    end

    private

    def generate_slug
      self.slug ||= name.parameterize if name.present?
    end
  end
end
