module Scheduling
  class CalendarConnection < ApplicationRecord
    belongs_to :member

    PROVIDERS = %w[google outlook].freeze

    validates :provider, inclusion: { in: PROVIDERS }
    validates :provider, uniqueness: { scope: :member_id }

    scope :active, -> { where(active: true) }
    scope :google, -> { where(provider: 'google') }
    scope :outlook, -> { where(provider: 'outlook') }

    def token_expired?
      token_expires_at.present? && token_expires_at < Time.current
    end

    def refresh_access_token!
      case provider
      when 'google'
        GoogleCalendarService.new(self).refresh_token
      when 'outlook'
        OutlookCalendarService.new(self).refresh_token
      end
    end
  end
end
