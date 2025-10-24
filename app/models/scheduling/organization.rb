module Scheduling
  class Organization < ApplicationRecord
    has_many :locations, dependent: :destroy
    has_many :teams, through: :locations
    has_many :members, through: :teams
    has_many :clients, dependent: :destroy

    validates :name, :slug, :timezone, presence: true
    validates :slug, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :default_currency, inclusion: { in: %w[PEN USD EUR GBP] }
    validates :default_locale, inclusion: { in: %w[es en pt fr] }

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
