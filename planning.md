# Schedulable - Rails 8 Multi-Tenant Scheduling Engine

## Project Overview

A comprehensive, production-ready Rails 8 engine for multi-tenant appointment scheduling with organizational hierarchy, custom questions, payment integration, and multi-language/currency support.

### Technology Stack
- **Rails 8.1+** with PostgreSQL
- **Tailwind CSS** for styling
- **esbuild** for JavaScript bundling
- **Hotwire** (Turbo + Stimulus) for interactivity
- **money-rails** for multi-currency support
- **Payment Gateways**: Stripe and Culqi
- **Calendar Integration**: Google Calendar and Outlook

### Organizational Structure
```
Organization (e.g., "Acme Medical Group")
  └── Location (e.g., "Downtown Clinic", "Westside Office")
      └── Team (e.g., "Cardiology", "Pediatrics")
          └── Member (e.g., "Dr. Smith", "Nurse Johnson")
              └── Client (e.g., "John Doe")
```

### Core Features
- Multi-tenant organization structure with role-based access
- Individual member schedules with availability management
- Custom booking questions (required/optional)
- Payment processing (Stripe + Culqi) with pay-now or pay-later options
- Client self-service: cancel and reschedule appointments
- Multi-language support (ES, EN, PT, FR) with browser detection
- Multi-currency support (PEN default, USD, EUR, GBP)
- Google Calendar and Outlook integration
- Email notifications with reminders

---

## Phase 1: Initial Rails Setup

### 1.1 Create New Rails Engine

```bash
# Create the engine
rails plugin new . --name=schedulable --mountable --database=postgresql --javascript=esbuild --css=tailwind --skip-solid

cd schedulable

# Add required gems to schedulable.gemspec
```

**File: `schedulable.gemspec`**
```ruby
Gem::Specification.new do |spec|
  spec.name        = "schedulable"
  spec.version     = "0.1.0"
  spec.authors     = ["Your Name"]
  spec.email       = ["your.email@example.com"]
  spec.summary     = "Multi-tenant scheduling engine for Rails"
  spec.description = "Complete scheduling solution with organizational hierarchy, payments, and calendar integration"
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 8.0"
  spec.add_dependency "pg", "~> 1.5"
  
  # Multi-currency support
  spec.add_dependency "money-rails", "~> 1.15"
  
  # Payment processing
  spec.add_dependency "stripe", "~> 10.0"
  spec.add_dependency "culqi-ruby", "~> 1.0"
  
  # Calendar integration
  spec.add_dependency "google-api-client", "~> 0.53"
  spec.add_dependency "microsoft_graph", "~> 1.0"
  
  # Scheduling logic
  spec.add_dependency "ice_cube", "~> 0.16"
  
  # Background jobs
  spec.add_dependency "solid_queue", "~> 0.1"
  
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.4"
  spec.add_development_dependency "faker", "~> 3.2"
end
```

### 1.2 Configure Database

**File: `spec/dummy/config/database.yml`**
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: schedulable_development

test:
  <<: *default
  database: schedulable_test
```

### 1.3 Configure Tailwind

**File: `tailwind.config.js`**
```javascript
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/components/**/*.{rb,erb}'
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        }
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
```

### 1.4 Configure Money Rails

**File: `config/initializers/money.rb`**
```ruby
MoneyRails.configure do |config|
  config.default_currency = :pen
  config.locale_backend = :i18n
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
  config.default_bank = Money::Bank::VariableExchange.new(Money::RatesStore::Memory.new)
  
  # Set exchange rates (update periodically via API in production)
  config.default_bank.add_rate('USD', 'PEN', 3.75)
  config.default_bank.add_rate('EUR', 'PEN', 4.10)
  config.default_bank.add_rate('GBP', 'PEN', 4.80)
end
```

### 1.5 Configure I18n

**File: `config/initializers/schedulable.rb`**
```ruby
require 'schedulable/configuration'

Schedulable.configure do |config|
  # Organization settings
  config.enable_multi_tenancy = true
  
  # I18n
  config.default_locale = :es
  config.available_locales = [:es, :en, :pt, :fr]
  config.detect_locale_from_browser = true
  
  # Currency
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']
  
  # Payment providers
  config.payment_providers = [:stripe, :culqi]
  
  # Policies
  config.default_cancellation_hours = 24
  config.default_rescheduling_hours = 24
  
  # Emails
  config.send_confirmation_emails = true
  config.send_reminder_emails = true
  config.reminder_hours_before = 24
  
  # Calendar integrations
  config.enable_google_calendar = true
  config.enable_outlook_calendar = true
end
```

**File: `lib/schedulable/configuration.rb`**
```ruby
module Schedulable
  class Configuration
    attr_accessor :enable_multi_tenancy,
                  :default_locale,
                  :available_locales,
                  :detect_locale_from_browser,
                  :default_currency,
                  :available_currencies,
                  :payment_providers,
                  :default_cancellation_hours,
                  :default_rescheduling_hours,
                  :send_confirmation_emails,
                  :send_reminder_emails,
                  :reminder_hours_before,
                  :enable_google_calendar,
                  :enable_outlook_calendar

    def initialize
      @enable_multi_tenancy = true
      @default_locale = :es
      @available_locales = [:es, :en, :pt, :fr]
      @detect_locale_from_browser = true
      @default_currency = 'PEN'
      @available_currencies = ['PEN', 'USD', 'EUR', 'GBP']
      @payment_providers = [:stripe, :culqi]
      @default_cancellation_hours = 24
      @default_rescheduling_hours = 24
      @send_confirmation_emails = true
      @send_reminder_emails = true
      @reminder_hours_before = 24
      @enable_google_calendar = true
      @enable_outlook_calendar = true
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
```

---

## Phase 2: Database Schema

### 2.1 Organization Structure Tables

**File: `db/migrate/001_create_schedulable_organizations.rb`**
```ruby
class CreateSchedulableOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, null: false, default: 'America/Lima'
      t.string :default_currency, default: 'PEN'
      t.string :default_locale, default: 'es'
      t.text :logo_url
      t.text :description
      t.boolean :active, default: true
      t.jsonb :settings, default: {}
      
      t.timestamps
      
      t.index :slug, unique: true
      t.index :active
    end

    create_table :schedulable_locations do |t|
      t.references :organization, null: false, foreign_key: { to_table: :schedulable_organizations }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :address
      t.string :city
      t.string :state
      t.string :country
      t.string :postal_code
      t.string :phone
      t.string :email
      t.string :timezone, null: false, default: 'America/Lima'
      t.boolean :active, default: true
      t.jsonb :settings, default: {}
      
      t.timestamps
      
      t.index [:organization_id, :slug], unique: true
      t.index :active
    end

    create_table :schedulable_teams do |t|
      t.references :location, null: false, foreign_key: { to_table: :schedulable_locations }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :color, default: '#3b82f6'
      t.boolean :active, default: true
      t.jsonb :settings, default: {}
      
      t.timestamps
      
      t.index [:location_id, :slug], unique: true
      t.index :active
    end

    create_table :schedulable_members do |t|
      t.references :team, null: false, foreign_key: { to_table: :schedulable_teams }
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'member' # admin, manager, member
      t.string :title # e.g., "Senior Doctor", "Nurse Practitioner"
      t.text :bio
      t.text :avatar_url
      t.string :booking_slug, null: false
      t.boolean :active, default: true
      t.boolean :accepts_bookings, default: true
      t.jsonb :settings, default: {}
      
      t.timestamps
      
      t.index :booking_slug, unique: true
      t.index [:team_id, :user_id], unique: true
      t.index :active
    end

    create_table :schedulable_clients do |t|
      t.references :organization, null: false, foreign_key: { to_table: :schedulable_organizations }
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone
      t.string :timezone, default: 'America/Lima'
      t.string :locale, default: 'es'
      t.text :notes
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index [:organization_id, :email], unique: true
      t.index :email
    end
  end
end
```

### 2.2 Scheduling Tables

**File: `db/migrate/002_create_schedulable_event_types.rb`**
```ruby
class CreateSchedulableEventTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_event_types do |t|
      t.references :member, null: false, foreign_key: { to_table: :schedulable_members }
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.string :location_type, default: 'in_person' # in_person, phone, video
      t.text :location_details
      t.integer :duration_minutes, null: false
      t.integer :buffer_before_minutes, default: 0
      t.integer :buffer_after_minutes, default: 0
      t.integer :minimum_notice_hours, default: 0
      t.integer :maximum_days_in_future, default: 60
      t.integer :slots_per_time_slot, default: 1
      t.string :color, default: '#3b82f6'
      t.boolean :active, default: true
      
      # Payment settings
      t.boolean :requires_payment, default: false
      t.integer :price_cents, default: 0
      t.string :price_currency, default: 'PEN'
      t.boolean :payment_required_to_book, default: true
      
      # Policies
      t.boolean :allow_rescheduling, default: true
      t.integer :rescheduling_policy_hours, default: 24
      t.boolean :allow_cancellation, default: true
      t.integer :cancellation_policy_hours, default: 24
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index [:member_id, :slug], unique: true
      t.index :active
    end
  end
end
```

**File: `db/migrate/003_create_schedulable_schedules.rb`**
```ruby
class CreateSchedulableSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_schedules do |t|
      t.references :member, null: false, foreign_key: { to_table: :schedulable_members }
      t.string :name, null: false
      t.string :timezone, null: false
      t.boolean :is_default, default: false
      
      t.timestamps
      
      t.index [:member_id, :is_default]
    end

    create_table :schedulable_availabilities do |t|
      t.references :schedule, null: false, foreign_key: { to_table: :schedulable_schedules }
      t.integer :day_of_week, null: false # 0-6 (Sunday-Saturday)
      t.time :start_time, null: false
      t.time :end_time, null: false
      
      t.timestamps
      
      t.index [:schedule_id, :day_of_week]
    end

    create_table :schedulable_date_overrides do |t|
      t.references :member, null: false, foreign_key: { to_table: :schedulable_members }
      t.date :date, null: false
      t.time :start_time
      t.time :end_time
      t.boolean :unavailable, default: false
      t.text :reason
      
      t.timestamps
      
      t.index [:member_id, :date]
    end
  end
end
```

**File: `db/migrate/004_create_schedulable_bookings.rb`**
```ruby
class CreateSchedulableBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_bookings do |t|
      t.references :event_type, null: false, foreign_key: { to_table: :schedulable_event_types }
      t.references :member, null: false, foreign_key: { to_table: :schedulable_members }
      t.references :client, null: false, foreign_key: { to_table: :schedulable_clients }
      
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :timezone, null: false
      
      t.string :status, default: 'confirmed' # confirmed, cancelled, rescheduled, completed, no_show
      t.string :cancellation_reason
      t.text :notes
      
      t.string :uid, null: false # Unique identifier for iCal
      t.string :reschedule_token
      t.string :cancellation_token
      t.references :rescheduled_from, foreign_key: { to_table: :schedulable_bookings }
      
      # Payment
      t.string :payment_status, default: 'not_required' # not_required, pending, paid, failed, refunded
      
      # External calendar IDs
      t.string :google_calendar_event_id
      t.string :outlook_calendar_event_id
      
      t.string :locale, default: 'es'
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :uid, unique: true
      t.index :reschedule_token, unique: true
      t.index :cancellation_token, unique: true
      t.index [:member_id, :start_time]
      t.index [:client_id, :start_time]
      t.index :status
      t.index :payment_status
    end

    create_table :schedulable_booking_changes do |t|
      t.references :booking, null: false, foreign_key: { to_table: :schedulable_bookings }
      t.string :change_type, null: false # cancelled, rescheduled, completed, no_show
      t.datetime :old_start_time
      t.datetime :old_end_time
      t.datetime :new_start_time
      t.datetime :new_end_time
      t.text :reason
      t.string :initiated_by # client, member, system
      
      t.timestamps
      
      t.index [:booking_id, :change_type]
      t.index :created_at
    end
  end
end
```

### 2.3 Custom Questions Tables

**File: `db/migrate/005_create_schedulable_booking_questions.rb`**
```ruby
class CreateSchedulableBookingQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_booking_questions do |t|
      t.references :event_type, null: false, foreign_key: { to_table: :schedulable_event_types }
      t.string :label, null: false
      t.string :question_type, null: false # text, textarea, email, phone, url, select, radio, checkbox, number, date
      t.text :options # JSON array for select/radio/checkbox
      t.boolean :required, default: false
      t.integer :position, default: 0
      t.text :placeholder
      t.text :help_text
      
      t.timestamps
      
      t.index [:event_type_id, :position]
    end

    create_table :schedulable_booking_answers do |t|
      t.references :booking, null: false, foreign_key: { to_table: :schedulable_bookings }
      t.references :booking_question, null: false, foreign_key: { to_table: :schedulable_booking_questions }
      t.text :answer
      
      t.timestamps
      
      t.index [:booking_id, :booking_question_id], name: 'index_booking_answers_on_booking_and_question'
    end
  end
end
```

### 2.4 Payment Tables

**File: `db/migrate/006_create_schedulable_payments.rb`**
```ruby
class CreateSchedulablePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_payments do |t|
      t.references :booking, null: false, foreign_key: { to_table: :schedulable_bookings }
      t.integer :amount_cents, null: false
      t.string :amount_currency, null: false
      t.string :status, default: 'pending' # pending, completed, failed, refunded
      t.string :payment_method # stripe, culqi, cash, transfer
      t.string :payment_provider # stripe, culqi
      t.string :external_transaction_id
      t.datetime :paid_at
      t.text :failure_reason
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :status
      t.index :external_transaction_id
      t.index [:booking_id, :status]
    end
  end
end
```

### 2.5 Calendar Integration Tables

**File: `db/migrate/007_create_schedulable_calendar_connections.rb`**
```ruby
class CreateSchedulableCalendarConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :schedulable_calendar_connections do |t|
      t.references :member, null: false, foreign_key: { to_table: :schedulable_members }
      t.string :provider, null: false # google, outlook
      t.string :external_calendar_id
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.boolean :check_for_conflicts, default: true
      t.boolean :add_bookings_to_calendar, default: true
      t.boolean :active, default: true
      
      t.timestamps
      
      t.index [:member_id, :provider], unique: true
    end
  end
end
```

---

## Phase 3: Models

### 3.1 Organization Models

**File: `app/models/schedulable/organization.rb`**
```ruby
module Schedulable
  class Organization < ApplicationRecord
    has_many :locations, dependent: :destroy
    has_many :teams, through: :locations
    has_many :members, through: :teams
    has_many :clients, dependent: :destroy
    
    validates :name, :slug, :timezone, presence: true
    validates :slug, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
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
```

**File: `app/models/schedulable/location.rb`**
```ruby
module Schedulable
  class Location < ApplicationRecord
    belongs_to :organization
    has_many :teams, dependent: :destroy
    has_many :members, through: :teams
    
    validates :name, :slug, :timezone, presence: true
    validates :slug, uniqueness: { scope: :organization_id }, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
    
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
```

**File: `app/models/schedulable/team.rb`**
```ruby
module Schedulable
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
```

**File: `app/models/schedulable/member.rb`**
```ruby
module Schedulable
  class Member < ApplicationRecord
    belongs_to :team
    belongs_to :user
    has_one :location, through: :team
    has_one :organization, through: :location
    
    has_many :event_types, dependent: :destroy
    has_many :schedules, dependent: :destroy
    has_many :date_overrides, dependent: :destroy
    has_many :bookings, dependent: :destroy
    has_many :calendar_connections, dependent: :destroy
    
    validates :role, inclusion: { in: %w[admin manager member] }
    validates :booking_slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :user_id, uniqueness: { scope: :team_id }
    
    before_validation :generate_booking_slug, on: :create
    
    scope :active, -> { where(active: true) }
    scope :accepting_bookings, -> { where(accepts_bookings: true, active: true) }
    scope :admins, -> { where(role: 'admin') }
    scope :managers, -> { where(role: %w[admin manager]) }
    
    def admin?
      role == 'admin'
    end
    
    def manager?
      role.in?(%w[admin manager])
    end
    
    def default_schedule
      schedules.find_by(is_default: true) || schedules.first
    end
    
    def public_booking_url
      Rails.application.routes.url_helpers.schedulable_member_booking_url(
        organization_slug: organization.slug,
        booking_slug: booking_slug
      )
    end
    
    def to_param
      booking_slug
    end
    
    private
    
    def generate_booking_slug
      if booking_slug.blank? && user.present?
        base_slug = [user.first_name, user.last_name].compact.join('-').parameterize
        self.booking_slug = base_slug
        
        counter = 1
        while Member.exists?(booking_slug: booking_slug)
          self.booking_slug = "#{base_slug}-#{counter}"
          counter += 1
        end
      end
    end
  end
end
```

**File: `app/models/schedulable/client.rb`**
```ruby
module Schedulable
  class Client < ApplicationRecord
    belongs_to :organization
    has_many :bookings, dependent: :destroy
    
    validates :email, :first_name, :last_name, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :organization_id }
    validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
    validates :locale, inclusion: { in: %w[es en pt fr] }
    
    def full_name
      "#{first_name} #{last_name}"
    end
    
    def upcoming_bookings
      bookings.where('start_time > ?', Time.current).order(:start_time)
    end
  end
end
```

### 3.2 Scheduling Models

**File: `app/models/schedulable/event_type.rb`**
```ruby
module Schedulable
  class EventType < ApplicationRecord
    belongs_to :member
    has_many :booking_questions, dependent: :destroy
    has_many :bookings, dependent: :destroy
    
    monetize :price_cents, with_currency: :price_currency
    
    validates :title, :slug, :duration_minutes, presence: true
    validates :slug, uniqueness: { scope: :member_id }, format: { with: /\A[a-z0-9\-]+\z/ }
    validates :duration_minutes, numericality: { greater_than: 0 }
    validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :location_type, inclusion: { in: %w[in_person phone video] }
    validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
    
    accepts_nested_attributes_for :booking_questions, allow_destroy: true
    
    before_validation :generate_slug, on: :create
    
    scope :active, -> { where(active: true) }
    scope :requiring_payment, -> { where(requires_payment: true) }
    
    def free?
      !requires_payment || price_cents.zero?
    end
    
    def payment_optional?
      requires_payment && !payment_required_to_book
    end
    
    def allows_cancellation_until
      return nil unless allow_cancellation
      cancellation_policy_hours.hours
    end
    
    def allows_rescheduling_until
      return nil unless allow_rescheduling
      rescheduling_policy_hours.hours
    end
    
    def public_booking_url
      Rails.application.routes.url_helpers.schedulable_public_booking_url(
        organization_slug: member.organization.slug,
        booking_slug: member.booking_slug,
        event_slug: slug
      )
    end
    
    def to_param
      slug
    end
    
    private
    
    def generate_slug
      self.slug ||= title.parameterize if title.present?
    end
  end
end
```

**File: `app/models/schedulable/schedule.rb`**
```ruby
module Schedulable
  class Schedule < ApplicationRecord
    belongs_to :member
    has_many :availabilities, dependent: :destroy
    
    validates :name, :timezone, presence: true
    validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
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
```

**File: `app/models/schedulable/availability.rb`**
```ruby
module Schedulable
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
```

**File: `app/models/schedulable/date_override.rb`**
```ruby
module Schedulable
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
```

### 3.3 Booking Models

**File: `app/models/schedulable/booking.rb`**
```ruby
module Schedulable
  class Booking < ApplicationRecord
    belongs_to :event_type
    belongs_to :member
    belongs_to :client
    belongs_to :rescheduled_from, class_name: 'Booking', optional: true
    
    has_many :booking_answers, dependent: :destroy
    has_many :booking_questions, through: :booking_answers
    has_one :payment, dependent: :destroy
    has_many :booking_changes, dependent: :destroy
    
    STATUSES = %w[confirmed cancelled rescheduled completed no_show].freeze
    PAYMENT_STATUSES = %w[not_required pending paid failed refunded].freeze
    
    validates :status, inclusion: { in: STATUSES }
    validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
    validates :start_time, :end_time, :timezone, presence: true
    validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
    validate :within_available_hours
    validate :no_conflicts
    validate :meets_minimum_notice
    validate :within_maximum_days
    validate :payment_completed_if_required
    validate :all_required_questions_answered
    
    before_validation :set_end_time, on: :create
    before_create :generate_tokens
    before_create :set_payment_status
    after_create :send_confirmation_email, if: -> { status == 'confirmed' }
    after_create :add_to_external_calendar, if: -> { status == 'confirmed' }
    
    scope :upcoming, -> { where('start_time > ?', Time.current) }
    scope :past, -> { where('start_time <= ?', Time.current) }
    scope :confirmed, -> { where(status: 'confirmed') }
    scope :requires_payment, -> { where(payment_status: 'pending') }
    scope :for_date, ->(date) { where('DATE(start_time) = ?', date) }
    
    accepts_nested_attributes_for :booking_answers
    
    def duration_minutes
      ((end_time - start_time) / 60).to_i
    end
    
    def can_cancel?
      return false unless status == 'confirmed'
      return false unless event_type.allow_cancellation
      
      policy_hours = event_type.cancellation_policy_hours
      return true if policy_hours.zero?
      
      start_time > (Time.current + policy_hours.hours)
    end
    
    def can_reschedule?
      return false unless status == 'confirmed'
      return false unless event_type.allow_rescheduling
      
      policy_hours = event_type.rescheduling_policy_hours
      return true if policy_hours.zero?
      
      start_time > (Time.current + policy_hours.hours)
    end
    
    def cancel!(reason: nil, initiated_by: 'client')
      raise 'Cannot cancel this booking' unless can_cancel?
      
      transaction do
        booking_changes.create!(
          change_type: 'cancelled',
          old_start_time: start_time,
          old_end_time: end_time,
          reason: reason,
          initiated_by: initiated_by
        )
        
        update!(
          status: 'cancelled',
          cancellation_reason: reason
        )
        
        process_refund if payment&.completed?
        send_cancellation_email
        remove_from_external_calendar
      end
    end
    
    def reschedule_to!(new_start_time, reason: nil, initiated_by: 'client')
      raise 'Cannot reschedule this booking' unless can_reschedule?
      
      new_end_time = new_start_time + event_type.duration_minutes.minutes
      
      transaction do
        booking_changes.create!(
          change_type: 'rescheduled',
          old_start_time: start_time,
          old_end_time: end_time,
          new_start_time: new_start_time,
          new_end_time: new_end_time,
          reason: reason,
          initiated_by: initiated_by
        )
        
        # Create new booking
        new_booking = dup
        new_booking.assign_attributes(
          start_time: new_start_time,
          end_time: new_end_time,
          rescheduled_from_id: id,
          status: 'confirmed',
          payment_status: payment_status
        )
        
        # Transfer payment if exists
        if payment&.completed?
          new_booking.build_payment(
            amount_cents: payment.amount_cents,
            amount_currency: payment.amount_currency,
            status: 'completed',
            payment_method: payment.payment_method,
            payment_provider: payment.payment_provider,
            paid_at: payment.paid_at
          )
        end
        
        # Copy answers
        booking_answers.each do |answer|
          new_booking.booking_answers.build(
            booking_question_id: answer.booking_question_id,
            answer: answer.answer
          )
        end
        
        new_booking.save!
        
        # Mark old booking as rescheduled
        update!(status: 'rescheduled')
        
        send_reschedule_email(new_booking)
        update_external_calendar(new_booking)
        
        new_booking
      end
    end
    
    def answer_for(question)
      booking_answers.find_by(booking_question: question)&.answer
    end
    
    def public_cancellation_url
      Rails.application.routes.url_helpers.schedulable_cancel_booking_url(
        token: cancellation_token,
        locale: locale
      )
    end
    
    def public_reschedule_url
      Rails.application.routes.url_helpers.schedulable_reschedule_booking_url(
        token: reschedule_token,
        locale: locale
      )
    end
    
    private
    
    def set_end_time
      self.end_time ||= start_time + event_type.duration_minutes.minutes if start_time && event_type
    end
    
    def generate_tokens
      self.uid ||= SecureRandom.uuid
      self.reschedule_token ||= SecureRandom.urlsafe_base64(32)
      self.cancellation_token ||= SecureRandom.urlsafe_base64(32)
    end
    
    def set_payment_status
      if event_type.requires_payment && event_type.payment_required_to_book
        self.payment_status = 'pending'
      else
        self.payment_status = 'not_required'
      end
    end
    
    def within_available_hours
      checker = AvailabilityChecker.new(member, event_type)
      unless checker.available_at?(start_time, duration_minutes)
        errors.add(:start_time, 'is not within available hours')
      end
    end
    
    def no_conflicts
      conflicting = member.bookings
                         .confirmed
                         .where.not(id: id)
                         .where('start_time < ? AND end_time > ?', end_time, start_time)
      
      if conflicting.exists?
        errors.add(:start_time, 'conflicts with another booking')
      end
    end
    
    def meets_minimum_notice
      required_notice = event_type.minimum_notice_hours.hours
      if start_time < (Time.current + required_notice)
        errors.add(:start_time, "requires at least #{event_type.minimum_notice_hours} hours notice")
      end
    end
    
    def within_maximum_days
      max_days = event_type.maximum_days_in_future
      if start_time > (Time.current + max_days.days)
        errors.add(:start_time, "cannot book more than #{max_days} days in advance")
      end
    end
    
    def payment_completed_if_required
      if event_type.requires_payment && event_type.payment_required_to_book
        unless payment_status == 'paid'
          errors.add(:payment_status, 'must be completed before booking')
        end
      end
    end
    
    def all_required_questions_answered
      required_questions = event_type.booking_questions.where(required: true)
      answered_question_ids = booking_answers.map(&:booking_question_id)
      
      required_questions.each do |question|
        unless answered_question_ids.include?(question.id)
          errors.add(:base, "#{question.label} is required")
        end
      end
    end
    
    def process_refund
      PaymentRefundJob.perform_later(payment.id)
    end
    
    def send_confirmation_email
      BookingConfirmationJob.perform_later(id)
    end
    
    def send_cancellation_email
      BookingCancellationJob.perform_later(id)
    end
    
    def send_reschedule_email(new_booking)
      BookingRescheduleJob.perform_later(id, new_booking.id)
    end
    
    def add_to_external_calendar
      CalendarSyncJob.perform_later(id, 'create')
    end
    
    def remove_from_external_calendar
      CalendarSyncJob.perform_later(id, 'delete')
    end
    
    def update_external_calendar(new_booking)
      CalendarSyncJob.perform_later(id, 'update', new_booking.id)
    end
  end
end
```

**File: `app/models/schedulable/booking_question.rb`**
```ruby
module Schedulable
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
```

**File: `app/models/schedulable/booking_answer.rb`**
```ruby
module Schedulable
  class BookingAnswer < ApplicationRecord
    belongs_to :booking
    belongs_to :booking_question
    
    validates :answer, presence: true, if: -> { booking_question.required? }
  end
end
```

**File: `app/models/schedulable/booking_change.rb`**
```ruby
module Schedulable
  class BookingChange < ApplicationRecord
    belongs_to :booking
    
    CHANGE_TYPES = %w[cancelled rescheduled completed no_show].freeze
    
    validates :change_type, inclusion: { in: CHANGE_TYPES }
    validates :initiated_by, inclusion: { in: %w[client member system] }
    
    scope :recent, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(change_type: type) }
  end
end
```

### 3.4 Payment Models

**File: `app/models/schedulable/payment.rb`**
```ruby
module Schedulable
  class Payment < ApplicationRecord
    belongs_to :booking
    
    monetize :amount_cents, with_currency: :amount_currency
    
    validates :amount_cents, :amount_currency, presence: true
    validates :status, inclusion: { in: %w[pending completed failed refunded] }
    validates :payment_provider, inclusion: { in: %w[stripe culqi] }, allow_nil: true
    
    scope :completed, -> { where(status: 'completed') }
    scope :pending, -> { where(status: 'pending') }
    scope :failed, -> { where(status: 'failed') }
    
    def completed?
      status == 'completed'
    end
    
    def mark_completed!(transaction_id:, payment_method:, payment_provider:)
      update!(
        status: 'completed',
        external_transaction_id: transaction_id,
        payment_method: payment_method,
        payment_provider: payment_provider,
        paid_at: Time.current
      )
      
      booking.update!(payment_status: 'paid')
    end
    
    def mark_failed!(reason:)
      update!(
        status: 'failed',
        failure_reason: reason
      )
      
      booking.update!(payment_status: 'failed')
    end
    
    def refund!(reason: nil)
      transaction do
        update!(status: 'refunded')
        booking.update!(payment_status: 'refunded')
        
        # Call payment processor's refund API
        case payment_provider
        when 'stripe'
          StripeRefundService.new(self).process
        when 'culqi'
          CulqiRefundService.new(self).process
        end
      end
    end
  end
end
```

### 3.5 Calendar Connection Model

**File: `app/models/schedulable/calendar_connection.rb`**
```ruby
module Schedulable
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
```

---

## Phase 4: Services

### 4.1 Availability Checker Service

**File: `app/services/schedulable/availability_checker.rb`**
```ruby
module Schedulable
  class AvailabilityChecker
    def initialize(member, event_type)
      @member = member
      @event_type = event_type
      @schedule = member.default_schedule
    end
    
    def available_slots(date_range, timezone = 'America/Lima')
      slots = []
      
      date_range.each do |date|
        # Check for date overrides first
        override = @member.date_overrides.find_by(date: date)
        
        if override&.unavailable?
          next
        elsif override
          slots.concat(generate_slots_for_override(date, override, timezone))
        else
          # Use weekly schedule
          availability = @schedule.availabilities.find_by(day_of_week: date.wday)
          slots.concat(generate_slots_for_availability(date, availability, timezone)) if availability
        end
      end
      
      # Filter out already booked slots
      filter_booked_slots(slots, timezone)
    end
    
    def available_at?(time, duration_minutes)
      # Apply buffers
      buffered_start = time - @event_type.buffer_before_minutes.minutes
      buffered_end = time + duration_minutes.minutes + @event_type.buffer_after_minutes.minutes
      
      # Check if within schedule
      return false unless within_schedule?(time)
      
      # Check for conflicts
      !has_conflicts?(buffered_start, buffered_end)
    end
    
    private
    
    def generate_slots_for_availability(date, availability, timezone)
      slots = []
      tz = ActiveSupport::TimeZone[timezone]
      
      current_time = tz.parse("#{date} #{availability.start_time}")
      end_time = tz.parse("#{date} #{availability.end_time}")
      
      # Apply minimum notice
      minimum_time = Time.current + @event_type.minimum_notice_hours.hours
      current_time = [current_time, minimum_time].max
      
      # Apply maximum days in future
      maximum_time = Time.current + @event_type.maximum_days_in_future.days
      end_time = [end_time, maximum_time].min
      
      while current_time + @event_type.duration_minutes.minutes <= end_time
        # Check if slot passes minimum notice and is not in the past
        if current_time > minimum_time
          slots << {
            start_time: current_time,
            end_time: current_time + @event_type.duration_minutes.minutes,
            available: true
          }
        end
        
        current_time += @event_type.duration_minutes.minutes
      end
      
      slots
    end
    
    def generate_slots_for_override(date, override, timezone)
      return [] if override.unavailable?
      
      tz = ActiveSupport::TimeZone[timezone]
      slots = []
      
      current_time = tz.parse("#{date} #{override.start_time}")
      end_time = tz.parse("#{date} #{override.end_time}")
      
      while current_time + @event_type.duration_minutes.minutes <= end_time
        slots << {
          start_time: current_time,
          end_time: current_time + @event_type.duration_minutes.minutes,
          available: true
        }
        current_time += @event_type.duration_minutes.minutes
      end
      
      slots
    end
    
    def filter_booked_slots(slots, timezone)
      slots.each do |slot|
        slot[:available] = !has_conflicts?(
          slot[:start_time] - @event_type.buffer_before_minutes.minutes,
          slot[:end_time] + @event_type.buffer_after_minutes.minutes
        )
        
        # Check external calendar conflicts if enabled
        if slot[:available]
          slot[:available] = !has_external_calendar_conflicts?(
            slot[:start_time],
            slot[:end_time]
          )
        end
      end
      
      slots.select { |slot| slot[:available] }
    end
    
    def within_schedule?(time)
      date = time.to_date
      override = @member.date_overrides.find_by(date: date)
      
      if override
        return false if override.unavailable?
        time_of_day = time.strftime('%H:%M:%S')
        return time_of_day >= override.start_time.strftime('%H:%M:%S') &&
               time_of_day < override.end_time.strftime('%H:%M:%S')
      end
      
      availability = @schedule.availabilities.find_by(day_of_week: date.wday)
      return false unless availability
      
      time_of_day = time.strftime('%H:%M:%S')
      time_of_day >= availability.start_time.strftime('%H:%M:%S') &&
        time_of_day < availability.end_time.strftime('%H:%M:%S')
    end
    
    def has_conflicts?(start_time, end_time)
      @member.bookings
             .confirmed
             .where('start_time < ? AND end_time > ?', end_time, start_time)
             .exists?
    end
    
    def has_external_calendar_conflicts?(start_time, end_time)
      @member.calendar_connections.active.each do |connection|
        next unless connection.check_for_conflicts
        
        service = case connection.provider
                  when 'google'
                    GoogleCalendarService.new(connection)
                  when 'outlook'
                    OutlookCalendarService.new(connection)
                  end
        
        return true if service.has_conflicts?(start_time, end_time)
      end
      
      false
    end
  end
end
```

### 4.2 Payment Services

**File: `app/services/schedulable/stripe_payment_service.rb`**
```ruby
module Schedulable
  class StripePaymentService
    def initialize(booking, payment_method_id)
      @booking = booking
      @payment_method_id = payment_method_id
      @event_type = booking.event_type
    end
    
    def process
      return { success: true } unless @event_type.requires_payment
      
      begin
        # Create payment intent
        intent = Stripe::PaymentIntent.create(
          amount: @event_type.price_cents,
          currency: @event_type.price_currency.downcase,
          payment_method: @payment_method_id,
          confirm: true,
          description: "Booking: #{@event_type.title} with #{@booking.member.user.full_name}",
          metadata: {
            booking_id: @booking.id,
            organization_id: @booking.member.organization.id
          }
        )
        
        if intent.status == 'succeeded'
          payment = @booking.create_payment!(
            amount_cents: intent.amount,
            amount_currency: intent.currency.upcase,
            status: 'completed',
            payment_method: 'card',
            payment_provider: 'stripe',
            external_transaction_id: intent.id,
            paid_at: Time.current
          )
          
          @booking.update!(payment_status: 'paid')
          
          { success: true, payment: payment }
        else
          { success: false, error: 'Payment failed' }
        end
      rescue Stripe::CardError => e
        { success: false, error: e.message }
      rescue Stripe::StripeError => e
        { success: false, error: 'Payment processing error' }
      end
    end
    
    def self.refund(payment)
      return unless payment.external_transaction_id.present?
      
      begin
        refund = Stripe::Refund.create(
          payment_intent: payment.external_transaction_id,
          reason: 'requested_by_customer'
        )
        
        payment.update!(status: 'refunded')
        true
      rescue Stripe::StripeError => e
        Rails.logger.error("Stripe refund failed: #{e.message}")
        false
      end
    end
  end
end
```

**File: `app/services/schedulable/culqi_payment_service.rb`**
```ruby
module Schedulable
  class CulqiPaymentService
    def initialize(booking, token_id)
      @booking = booking
      @token_id = token_id
      @event_type = booking.event_type
    end
    
    def process
      return { success: true } unless @event_type.requires_payment
      
      begin
        # Create charge with Culqi
        charge = Culqi::Charge.create(
          amount: @event_type.price_cents,
          currency_code: @event_type.price_currency,
          email: @booking.client.email,
          source_id: @token_id,
          description: "Booking: #{@event_type.title}",
          metadata: {
            booking_id: @booking.id.to_s,
            organization_id: @booking.member.organization.id.to_s
          }
        )
        
        if charge.outcome['type'] == 'venta_exitosa'
          payment = @booking.create_payment!(
            amount_cents: charge.amount,
            amount_currency: charge.currency_code,
            status: 'completed',
            payment_method: 'card',
            payment_provider: 'culqi',
            external_transaction_id: charge.id,
            paid_at: Time.current
          )
          
          @booking.update!(payment_status: 'paid')
          
          { success: true, payment: payment }
        else
          { success: false, error: charge.outcome['merchant_message'] }
        end
      rescue Culqi::Error => e
        { success: false, error: e.message }
      end
    end
    
    def self.refund(payment)
      return unless payment.external_transaction_id.present?
      
      begin
        refund = Culqi::Refund.create(
          amount: payment.amount_cents,
          charge_id: payment.external_transaction_id,
          reason: 'solicitud_comprador'
        )
        
        payment.update!(status: 'refunded')
        true
      rescue Culqi::Error => e
        Rails.logger.error("Culqi refund failed: #{e.message}")
        false
      end
    end
  end
end
```

### 4.3 Calendar Services

**File: `app/services/schedulable/google_calendar_service.rb`**
```ruby
module Schedulable
  class GoogleCalendarService
    def initialize(calendar_connection)
      @connection = calendar_connection
      @member = calendar_connection.member
    end
    
    def add_booking(booking)
      return unless @connection.add_bookings_to_calendar?
      
      client = authorized_client
      event = Google::Apis::CalendarV3::Event.new(
        summary: "#{booking.event_type.title} - #{booking.client.full_name}",
        description: booking.notes,
        start: {
          date_time: booking.start_time.iso8601,
          time_zone: booking.timezone
        },
        end: {
          date_time: booking.end_time.iso8601,
          time_zone: booking.timezone
        },
        attendees: [
          { email: booking.client.email, display_name: booking.client.full_name }
        ],
        reminders: {
          use_default: false,
          overrides: [
            { method: 'email', minutes: 24 * 60 },
            { method: 'popup', minutes: 30 }
          ]
        }
      )
      
      result = client.insert_event('primary', event)
      booking.update!(google_calendar_event_id: result.id)
      
      result
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to add booking to Google Calendar: #{e.message}")
      nil
    end
    
    def update_booking(booking)
      return unless booking.google_calendar_event_id.present?
      
      client = authorized_client
      event = client.get_event('primary', booking.google_calendar_event_id)
      
      event.start.date_time = booking.start_time.iso8601
      event.end.date_time = booking.end_time.iso8601
      
      client.update_event('primary', event.id, event)
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to update Google Calendar event: #{e.message}")
    end
    
    def delete_booking(booking)
      return unless booking.google_calendar_event_id.present?
      
      client = authorized_client
      client.delete_event('primary', booking.google_calendar_event_id)
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to delete Google Calendar event: #{e.message}")
    end
    
    def has_conflicts?(start_time, end_time)
      client = authorized_client
      events = client.list_events(
        'primary',
        time_min: start_time.iso8601,
        time_max: end_time.iso8601,
        single_events: true
      )
      
      events.items.any?
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to check Google Calendar conflicts: #{e.message}")
      false
    end
    
    def refresh_token
      # Implement OAuth token refresh logic
      # Update @connection.access_token and @connection.token_expires_at
    end
    
    private
    
    def authorized_client
      client = Google::Apis::CalendarV3::CalendarService.new
      client.authorization = authorization
      client
    end
    
    def authorization
      # Set up Google OAuth2 authorization
      # Use @connection.access_token and @connection.refresh_token
    end
  end
end
```

**File: `app/services/schedulable/outlook_calendar_service.rb`**
```ruby
module Schedulable
  class OutlookCalendarService
    def initialize(calendar_connection)
      @connection = calendar_connection
      @member = calendar_connection.member
    end
    
    def add_booking(booking)
      return unless @connection.add_bookings_to_calendar?
      
      # Implement Outlook Calendar API integration
      # Similar structure to Google Calendar service
    end
    
    def update_booking(booking)
      # Implement update logic
    end
    
    def delete_booking(booking)
      # Implement delete logic
    end
    
    def has_conflicts?(start_time, end_time)
      # Implement conflict checking
      false
    end
    
    def refresh_token
      # Implement OAuth token refresh
    end
  end
end
```

---

## Phase 5: Controllers

### 5.1 Public Booking Controller

**File: `app/controllers/schedulable/public_bookings_controller.rb`**
```ruby
module Schedulable
  class PublicBookingsController < ApplicationController
    before_action :set_locale
    before_action :find_member, only: [:index, :new, :create]
    before_action :find_event_type, only: [:new, :create]
    before_action :find_booking_by_token, only: [:show, :cancel, :process_cancellation, :reschedule, :process_reschedule]
    
    def index
      @event_types = @member.event_types.active
    end
    
    def new
      @booking = @event_type.bookings.build
      @booking_questions = @event_type.booking_questions.ordered
      @available_dates = calculate_available_dates
    end
    
    def create
      @client = find_or_create_client
      
      @booking = @event_type.bookings.build(booking_params)
      @booking.member = @member
      @booking.client = @client
      @booking.locale = I18n.locale.to_s
      
      # Build answers
      build_booking_answers if params[:answers].present?
      
      # Handle payment if required
      if @event_type.requires_payment && @event_type.payment_required_to_book
        payment_result = process_payment
        
        unless payment_result[:success]
          @booking.errors.add(:base, payment_result[:error])
          @booking_questions = @event_type.booking_questions.ordered
          render :new and return
        end
      end
      
      if @booking.save
        redirect_to schedulable_booking_confirmation_path(@booking.uid, locale: I18n.locale)
      else
        @booking_questions = @event_type.booking_questions.ordered
        @available_dates = calculate_available_dates
        render :new
      end
    end
    
    def show
      # Confirmation page
    end
    
    def cancel
      # Cancellation form
    end
    
    def process_cancellation
      if @booking.can_cancel?
        @booking.cancel!(
          reason: params[:reason],
          initiated_by: 'client'
        )
        flash[:notice] = t('schedulable.bookings.cancel.success')
        redirect_to root_path
      else
        flash[:alert] = t('schedulable.errors.past_cancellation_deadline',
                         hours: @booking.event_type.cancellation_policy_hours)
        render :cancel
      end
    end
    
    def reschedule
      @available_dates = calculate_available_dates
    end
    
    def process_reschedule
      new_start_time = DateTime.parse(params[:new_start_time])
      
      if @booking.can_reschedule?
        new_booking = @booking.reschedule_to!(
          new_start_time,
          reason: params[:reason],
          initiated_by: 'client'
        )
        flash[:notice] = t('schedulable.bookings.reschedule.success')
        redirect_to schedulable_booking_confirmation_path(new_booking.uid, locale: I18n.locale)
      else
        flash[:alert] = t('schedulable.errors.past_reschedule_deadline',
                         hours: @booking.event_type.rescheduling_policy_hours)
        @available_dates = calculate_available_dates
        render :reschedule
      end
    end
    
    def availability
      member = Member.find(params[:member_id])
      event_type = member.event_types.find(params[:event_type_id])
      date = Date.parse(params[:date])
      timezone = params[:timezone] || 'America/Lima'
      
      checker = AvailabilityChecker.new(member, event_type)
      @slots = checker.available_slots(date..date, timezone)
      
      respond_to do |format|
        format.turbo_stream
        format.html { render partial: 'time_slots', locals: { slots: @slots } }
      end
    end
    
    private
    
    def set_locale
      if Schedulable.configuration.detect_locale_from_browser
        browser_locale = extract_locale_from_accept_language_header
        I18n.locale = params[:locale] || browser_locale || Schedulable.configuration.default_locale
      else
        I18n.locale = params[:locale] || Schedulable.configuration.default_locale
      end
    end
    
    def extract_locale_from_accept_language_header
      return nil unless request.env['HTTP_ACCEPT_LANGUAGE']
      
      accepted = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
      Schedulable.configuration.available_locales.include?(accepted.to_sym) ? accepted : nil
    end
    
    def find_member
      @organization = Organization.find_by!(slug: params[:organization_slug])
      @member = @organization.members.find_by!(booking_slug: params[:booking_slug])
    end
    
    def find_event_type
      @event_type = @member.event_types.active.find_by!(slug: params[:event_slug])
    end
    
    def find_booking_by_token
      token = params[:token]
      @booking = Booking.find_by(cancellation_token: token) || 
                 Booking.find_by(reschedule_token: token)
      
      redirect_to root_path, alert: 'Booking not found' unless @booking
    end
    
    def find_or_create_client
      @organization.clients.find_or_create_by!(
        email: booking_params[:client_email]
      ) do |client|
        client.first_name = booking_params[:client_first_name]
        client.last_name = booking_params[:client_last_name]
        client.phone = booking_params[:client_phone]
        client.timezone = booking_params[:timezone]
        client.locale = I18n.locale.to_s
      end
    end
    
    def booking_params
      params.require(:booking).permit(
        :start_time, :timezone, :notes,
        :client_first_name, :client_last_name, :client_email, :client_phone
      )
    end
    
    def build_booking_answers
      params[:answers].each do |question_id, answer|
        next if answer.blank?
        
        @booking.booking_answers.build(
          booking_question_id: question_id,
          answer: answer.is_a?(Array) ? answer.to_json : answer
        )
      end
    end
    
    def process_payment
      provider = params[:payment_provider] || 'stripe'
      
      case provider
      when 'stripe'
        StripePaymentService.new(@booking, params[:payment_method_id]).process
      when 'culqi'
        CulqiPaymentService.new(@booking, params[:token_id]).process
      else
        { success: false, error: 'Invalid payment provider' }
      end
    end
    
    def calculate_available_dates
      start_date = Date.current
      end_date = start_date + @event_type.maximum_days_in_future.days
      start_date..end_date
    end
  end
end
```

### 5.2 Admin Controllers (Organization/Location/Team/Member Management)

Create admin controllers for:
- `OrganizationsController`
- `LocationsController`
- `TeamsController`
- `MembersController`
- `EventTypesController`
- `SchedulesController`
- `BookingsController`

These should follow standard Rails CRUD patterns with proper authorization.

---

## Phase 6: Views

### 6.1 Public Booking View

**File: `app/views/schedulable/public_bookings/new.html.erb`**
```erb
<div class="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-5xl mx-auto">
    <!-- Header -->
    <div class="text-center mb-8">
      <div class="flex items-center justify-center mb-4">
        <% if @member.avatar_url.present? %>
          <%= image_tag @member.avatar_url, class: "h-16 w-16 rounded-full" %>
        <% end %>
        <div class="ml-4 text-left">
          <h1 class="text-3xl font-bold text-gray-900">
            <%= @event_type.title %>
          </h1>
          <p class="text-lg text-gray-600">
            <%= t('schedulable.bookings.new.with') %> <%= @member.user.full_name %>
          </p>
        </div>
      </div>
      
      <div class="flex items-center justify-center space-x-4 text-sm text-gray-600">
        <span class="flex items-center">
          <%= inline_svg_tag "icons/clock.svg", class: "h-4 w-4 mr-1" %>
          <%= @event_type.duration_minutes %> <%= t('schedulable.common.minutes') %>
        </span>
        
        <% if @event_type.requires_payment %>
          <span class="flex items-center">
            <%= inline_svg_tag "icons/currency.svg", class: "h-4 w-4 mr-1" %>
            <%= humanized_money_with_symbol(@event_type.price) %>
          </span>
        <% end %>
        
        <span class="flex items-center">
          <%= inline_svg_tag "icons/location.svg", class: "h-4 w-4 mr-1" %>
          <%= @event_type.location_type.humanize %>
        </span>
      </div>
      
      <!-- Language Switcher -->
      <div class="mt-4 flex justify-center space-x-2">
        <% Schedulable.configuration.available_locales.each do |locale| %>
          <%= link_to locale.upcase,
              request.params.merge(locale: locale),
              class: "px-3 py-1 rounded transition #{I18n.locale == locale ? 'bg-primary-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-100'}" %>
        <% end %>
      </div>
    </div>

    <%= form_with model: @booking, 
                  url: schedulable_bookings_path,
                  data: { 
                    controller: "booking-form",
                    booking_form_event_type_id_value: @event_type.id,
                    booking_form_member_id_value: @member.id
                  },
                  class: "bg-white shadow-lg rounded-lg overflow-hidden" do |f| %>
      
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 p-8">
        <!-- Left Column: Date & Time Selection -->
        <div>
          <h2 class="text-xl font-semibold text-gray-900 mb-4">
            <%= t('schedulable.bookings.new.select_date_time') %>
          </h2>
          
          <!-- Calendar -->
          <div data-controller="calendar" 
               data-calendar-member-id-value="<%= @member.id %>"
               data-calendar-event-type-id-value="<%= @event_type.id %>"
               data-calendar-timezone-value="<%= @member.location.timezone %>"
               class="mb-6">
            
            <div class="bg-white border border-gray-200 rounded-lg p-4">
              <%= month_calendar(
                attribute: :start_time,
                start_date: Date.current,
                data: { 
                  action: "click->calendar#dateSelected",
                  calendar_target: "month" 
                }
              ) do |date, _events| %>
                <div class="text-center p-2 cursor-pointer hover:bg-primary-50 rounded"
                     data-date="<%= date.iso8601 %>">
                  <%= date.day %>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Time Slots -->
          <div class="mt-6" data-calendar-target="slots">
            <h3 class="text-lg font-medium text-gray-900 mb-3">
              <%= t('schedulable.bookings.new.select_time') %>
            </h3>
            <div id="time-slots" class="grid grid-cols-3 gap-2">
              <p class="col-span-3 text-center text-gray-500 py-8">
                <%= t('schedulable.bookings.new.select_date_first') %>
              </p>
            </div>
          </div>
        </div>

        <!-- Right Column: Booking Information -->
        <div>
          <h2 class="text-xl font-semibold text-gray-900 mb-4">
            <%= t('schedulable.bookings.new.your_information') %>
          </h2>
          
          <div class="space-y-4">
            <!-- Client Information -->
            <div class="grid grid-cols-2 gap-4">
              <div>
                <%= label_tag :client_first_name, t('schedulable.bookings.new.first_name'),
                             class: "block text-sm font-medium text-gray-700" %>
                <%= text_field_tag 'booking[client_first_name]', nil,
                                  required: true,
                                  class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>
              </div>
              
              <div>
                <%= label_tag :client_last_name, t('schedulable.bookings.new.last_name'),
                             class: "block text-sm font-medium text-gray-700" %>
                <%= text_field_tag 'booking[client_last_name]', nil,
                                  required: true,
                                  class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>
              </div>
            </div>

            <div>
              <%= label_tag :client_email, t('schedulable.bookings.new.email'),
                           class: "block text-sm font-medium text-gray-700" %>
              <%= email_field_tag 'booking[client_email]', nil,
                                 required: true,
                                 class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>
            </div>

            <div>
              <%= label_tag :client_phone, t('schedulable.bookings.new.phone'),
                           class: "block text-sm font-medium text-gray-700" %>
              <%= telephone_field_tag 'booking[client_phone]', nil,
                                     class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>
            </div>

            <div>
              <%= f.label :timezone, t('schedulable.bookings.new.timezone'),
                         class: "block text-sm font-medium text-gray-700" %>
              <%= f.time_zone_select :timezone, 
                                     ActiveSupport::TimeZone.all,
                                     { default: @member.location.timezone },
                                     class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>
            </div>
            
            <!-- Custom Questions -->
            <% @booking_questions.each do |question| %>
              <div>
                <%= label_tag "answers[#{question.id}]", class: "block text-sm font-medium text-gray-700" do %>
                  <%= question.label %>
                  <% if question.required %>
                    <span class="text-red-500">*</span>
                  <% else %>
                    <span class="text-gray-500 text-xs">
                      (<%= t('schedulable.questions.optional') %>)
                    </span>
                  <% end %>
                <% end %>
                
                <% if question.help_text.present? %>
                  <p class="text-xs text-gray-500 mt-1"><%= question.help_text %></p>
                <% end %>
                
                <%= render "schedulable/booking_questions/field", question: question %>
              </div>
            <% end %>
            
            <div>
              <%= f.label :notes, t('schedulable.bookings.new.notes'),
                         class: "block text-sm font-medium text-gray-700" %>
              <%= f.text_area :notes,
                             rows: 3,
                             class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>
            </div>
          </div>
          
          <!-- Payment Section -->
          <% if @event_type.requires_payment %>
            <div class="mt-6 p-4 bg-primary-50 rounded-lg">
              <h3 class="text-lg font-medium text-gray-900 mb-2">
                <%= t('schedulable.payment.required') %>
              </h3>
              <p class="text-2xl font-bold text-primary-600">
                <%= humanized_money_with_symbol(@event_type.price) %>
              </p>
              
              <% if @event_type.payment_required_to_book %>
                <!-- Payment Gateway Selection -->
                <div class="mt-4">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    <%= t('schedulable.payment.method') %>
                  </label>
                  
                  <div class="space-y-2">
                    <label class="flex items-center p-3 border border-gray-300 rounded-md cursor-pointer hover:bg-gray-50">
                      <%= radio_button_tag :payment_provider, 'stripe', true,
                                          data: { action: "change->booking-form#paymentProviderChanged" } %>
                      <span class="ml-2">Credit/Debit Card (Stripe)</span>
                    </label>
                    
                    <label class="flex items-center p-3 border border-gray-300 rounded-md cursor-pointer hover:bg-gray-50">
                      <%= radio_button_tag :payment_provider, 'culqi', false,
                                          data: { action: "change->booking-form#paymentProviderChanged" } %>
                      <span class="ml-2">Tarjeta (Culqi)</span>
                    </label>
                  </div>
                </div>
                
                <!-- Stripe Elements -->
                <div id="stripe-payment" class="mt-4" data-booking-form-target="stripePayment">
                  <div id="stripe-card-element" class="p-3 border border-gray-300 rounded-md bg-white"></div>
                  <div id="stripe-card-errors" class="text-red-600 text-sm mt-2"></div>
                </div>
                
                <!-- Culqi Elements -->
                <div id="culqi-payment" class="mt-4 hidden" data-booking-form-target="culqiPayment">
                  <div id="culqi-card-element" class="p-3 border border-gray-300 rounded-md bg-white"></div>
                  <div id="culqi-card-errors" class="text-red-600 text-sm mt-2"></div>
                </div>
              <% else %>
                <div class="mt-4 space-y-2">
                  <label class="flex items-center">
                    <%= radio_button_tag 'payment_timing', 'now', false,
                                        data: { action: "change->booking-form#paymentTimingChanged" } %>
                    <span class="ml-2"><%= t('schedulable.bookings.new.pay_now') %></span>
                  </label>
                  
                  <label class="flex items-center">
                    <%= radio_button_tag 'payment_timing', 'later', true,
                                        data: { action: "change->booking-form#paymentTimingChanged" } %>
                    <span class="ml-2"><%= t('schedulable.bookings.new.pay_later') %></span>
                  </label>
                </div>
              <% end %>
            </div>
          <% end %>
          
          <!-- Hidden fields -->
          <%= f.hidden_field :start_time, data: { booking_form_target: "startTime" } %>
          
          <!-- Submit Button -->
          <div class="mt-6">
            <%= f.submit t('schedulable.bookings.new.book_appointment'),
                        class: "w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 disabled:opacity-50 disabled:cursor-not-allowed transition",
                        data: { 
                          booking_form_target: "submit",
                          disable_with: t('schedulable.bookings.new.processing')
                        } %>
          </div>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

**File: `app/views/schedulable/booking_questions/_field.html.erb`**
```erb
<% case question.question_type %>
<% when 'text', 'url' %>
  <%= text_field_tag "answers[#{question.id}]",
                     nil,
                     type: question.question_type,
                     required: question.required,
                     placeholder: question.placeholder,
                     class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'email' %>
  <%= email_field_tag "answers[#{question.id}]",
                      nil,
                      required: question.required,
                      placeholder: question.placeholder,
                      class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'phone' %>
  <%= telephone_field_tag "answers[#{question.id}]",
                          nil,
                          required: question.required,
                          placeholder: question.placeholder,
                          class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'textarea' %>
  <%= text_area_tag "answers[#{question.id}]",
                    nil,
                    required: question.required,
                    placeholder: question.placeholder,
                    rows: 3,
                    class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'number' %>
  <%= number_field_tag "answers[#{question.id}]",
                       nil,
                       required: question.required,
                       placeholder: question.placeholder,
                       class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'date' %>
  <%= date_field_tag "answers[#{question.id}]",
                     nil,
                     required: question.required,
                     class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'select' %>
  <%= select_tag "answers[#{question.id}]",
                 options_for_select(question.options_array),
                 { include_blank: t('schedulable.common.select'), required: question.required },
                 class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500" %>

<% when 'radio' %>
  <div class="mt-2 space-y-2">
    <% question.options_array.each_with_index do |option, index| %>
      <label class="flex items-center">
        <%= radio_button_tag "answers[#{question.id}]",
                            option,
                            false,
                            required: question.required,
                            id: "question_#{question.id}_option_#{index}",
                            class: "h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300" %>
        <span class="ml-2 text-sm text-gray-700"><%= option %></span>
      </label>
    <% end %>
  </div>

<% when 'checkbox' %>
  <div class="mt-2 space-y-2">
    <% question.options_array.each_with_index do |option, index| %>
      <label class="flex items-center">
        <%= check_box_tag "answers[#{question.id}][]",
                         option,
                         false,
                         id: "question_#{question.id}_option_#{index}",
                         class: "h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded" %>
        <span class="ml-2 text-sm text-gray-700"><%= option %></span>
      </label>
    <% end %>
  </div>
<% end %>
```

---

## Phase 7: JavaScript (Stimulus Controllers)

### 7.1 Booking Form Controller

**File: `app/javascript/schedulable/controllers/booking_form_controller.js`**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "startTime", "stripePayment", "culqiPayment"]
  static values = {
    eventTypeId: Number,
    memberId: Number,
    stripePublishableKey: String,
    culqiPublicKey: String
  }

  connect() {
    this.initializePaymentProviders()
  }

  initializePaymentProviders() {
    // Initialize Stripe
    if (typeof Stripe !== 'undefined') {
      this.stripe = Stripe(this.stripePublishableKeyValue)
      this.stripeElements = this.stripe.elements()
      this.stripeCard = this.stripeElements.create('card')
      this.stripeCard.mount('#stripe-card-element')
      
      this.stripeCard.on('change', (event) => {
        const displayError = document.getElementById('stripe-card-errors')
        if (event.error) {
          displayError.textContent = event.error.message
        } else {
          displayError.textContent = ''
        }
      })
    }

    // Initialize Culqi
    if (typeof Culqi !== 'undefined') {
      Culqi.publicKey = this.culqiPublicKeyValue
      Culqi.init()
    }
  }

  async submit(event) {
    event.preventDefault()
    
    const form = event.target
    const paymentRequired = document.querySelector('input[name="payment_timing"]:checked')?.value === 'now'
    
    if (paymentRequired) {
      const provider = document.querySelector('input[name="payment_provider"]:checked')?.value
      
      if (provider === 'stripe') {
        await this.processStripePayment(form)
      } else if (provider === 'culqi') {
        await this.processCulqiPayment(form)
      }
    } else {
      form.submit()
    }
  }

  async processStripePayment(form) {
    const { paymentMethod, error } = await this.stripe.createPaymentMethod({
      type: 'card',
      card: this.stripeCard,
    })

    if (error) {
      document.getElementById('stripe-card-errors').textContent = error.message
    } else {
      // Add payment method ID to form
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = 'payment_method_id'
      input.value = paymentMethod.id
      form.appendChild(input)
      
      form.submit()
    }
  }

  async processCulqiPayment(form) {
    // Culqi implementation
    // Get card data and create token
    Culqi.createToken()
  }

  paymentProviderChanged(event) {
    const provider = event.target.value
    
    if (provider === 'stripe') {
      this.stripePaymentTarget.classList.remove('hidden')
      this.culqiPaymentTarget.classList.add('hidden')
    } else if (provider === 'culqi') {
      this.stripePaymentTarget.classList.add('hidden')
      this.culqiPaymentTarget.classList.remove('hidden')
    }
  }

  paymentTimingChanged(event) {
    const timing = event.target.value
    // Show/hide payment elements based on timing
  }
}
```

### 7.2 Calendar Controller

**File: `app/javascript/schedulable/controllers/calendar_controller.js`**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["month", "slots"]
  static values = {
    memberId: Number,
    eventTypeId: Number,
    timezone: String
  }

  async dateSelected(event) {
    const dateCell = event.target.closest('[data-date]')
    if (!dateCell) return
    
    const selectedDate = dateCell.dataset.date
    
    // Highlight selected date
    this.monthTarget.querySelectorAll('[data-date]').forEach(cell => {
      cell.classList.remove('bg-primary-500', 'text-white')
      cell.classList.add('hover:bg-primary-50')
    })
    dateCell.classList.add('bg-primary-500', 'text-white')
    dateCell.classList.remove('hover:bg-primary-50')
    
    // Fetch available time slots
    await this.loadTimeSlots(selectedDate)
  }

  async loadTimeSlots(date) {
    const url = `/schedulable/availability?` +
                `member_id=${this.memberIdValue}&` +
                `event_type_id=${this.eventTypeIdValue}&` +
                `date=${date}&` +
                `timezone=${this.timezoneValue || Intl.DateTimeFormat().resolvedOptions().timeZone}`
    
    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.slotsTarget.innerHTML = html
      }
    } catch (error) {
      console.error('Error loading time slots:', error)
      this.slotsTarget.innerHTML = '<p class="text-red-600">Error loading available times</p>'
    }
  }

  selectTimeSlot(event) {
    const slot = event.currentTarget
    
    // Highlight selected slot
    this.slotsTarget.querySelectorAll('.time-slot').forEach(s => {
      s.classList.remove('ring-2', 'ring-primary-500', 'bg-primary-50')
    })
    slot.classList.add('ring-2', 'ring-primary-500', 'bg-primary-50')
    
    // Set hidden field values
    const startTimeInput = document.querySelector('[data-booking-form-target="startTime"]')
    if (startTimeInput) {
      startTimeInput.value = slot.dataset.startTime
    }
    
    // Enable submit button
    const submitButton = document.querySelector('[data-booking-form-target="submit"]')
    if (submitButton) {
      submitButton.disabled = false
    }
  }
}
```

---

## Phase 8: Background Jobs

**File: `app/jobs/schedulable/booking_confirmation_job.rb`**
```ruby
module Schedulable
  class BookingConfirmationJob < ApplicationJob
    queue_as :default

    def perform(booking_id)
      booking = Booking.find(booking_id)
      BookingMailer.confirmation(booking).deliver_now
    end
  end
end
```

**File: `app/jobs/schedulable/booking_cancellation_job.rb`**
```ruby
module Schedulable
  class BookingCancellationJob < ApplicationJob
    queue_as :default

    def perform(booking_id)
      booking = Booking.find(booking_id)
      BookingMailer.cancellation(booking).deliver_now
    end
  end
end
```

**File: `app/jobs/schedulable/booking_reschedule_job.rb`**
```ruby
module Schedulable
  class BookingRescheduleJob < ApplicationJob
    queue_as :default

    def perform(old_booking_id, new_booking_id)
      old_booking = Booking.find(old_booking_id)
      new_booking = Booking.find(new_booking_id)
      BookingMailer.rescheduled(old_booking, new_booking).deliver_now
    end
  end
end
```

**File: `app/jobs/schedulable/calendar_sync_job.rb`**
```ruby
module Schedulable
  class CalendarSyncJob < ApplicationJob
    queue_as :default

    def perform(booking_id, action, new_booking_id = nil)
      booking = Booking.find(booking_id)
      member = booking.member
      
      member.calendar_connections.active.each do |connection|
        service = case connection.provider
                  when 'google'
                    GoogleCalendarService.new(connection)
                  when 'outlook'
                    OutlookCalendarService.new(connection)
                  end
        
        case action
        when 'create'
          service.add_booking(booking)
        when 'delete'
          service.delete_booking(booking)
        when 'update'
          new_booking = Booking.find(new_booking_id)
          service.delete_booking(booking)
          service.add_booking(new_booking)
        end
      end
    end
  end
end
```

**File: `app/jobs/schedulable/payment_refund_job.rb`**
```ruby
module Schedulable
  class PaymentRefundJob < ApplicationJob
    queue_as :default

    def perform(payment_id)
      payment = Payment.find(payment_id)
      
      case payment.payment_provider
      when 'stripe'
        StripePaymentService.refund(payment)
      when 'culqi'
        CulqiPaymentService.refund(payment)
      end
    end
  end
end
```

---

## Phase 9: Routes

**File: `config/routes.rb`**
```ruby
Schedulable::Engine.routes.draw do
  scope '(:locale)', locale: /#{Schedulable.configuration.available_locales.join('|')}/ do
    # Public booking routes
    get ':organization_slug/:booking_slug', to: 'public_bookings#index', as: :member_booking
    get ':organization_slug/:booking_slug/:event_slug', to: 'public_bookings#new', as: :public_booking
    post ':organization_slug/:booking_slug/:event_slug', to: 'public_bookings#create', as: :bookings
    
    # Booking management
    get 'booking/:uid', to: 'public_bookings#show', as: :booking_confirmation
    get 'booking/:token/cancel', to: 'public_bookings#cancel', as: :cancel_booking
    post 'booking/:token/cancel', to: 'public_bookings#process_cancellation'
    get 'booking/:token/reschedule', to: 'public_bookings#reschedule', as: :reschedule_booking
    post 'booking/:token/reschedule', to: 'public_bookings#process_reschedule'
    
    # Availability check (AJAX endpoint)
    get 'availability', to: 'public_bookings#availability'
    
    # Admin routes
    namespace :admin do
      resources :organizations do
        resources :locations do
          resources :teams do
            resources :members do
              resources :event_types do
                resources :booking_questions
              end
              resources :schedules do
                resources :availabilities
              end
              resources :date_overrides
            end
          end
        end
        resources :clients
      end
      
      resources :bookings do
        member do
          patch :complete
          patch :mark_no_show
        end
      end
      
      resources :calendar_connections do
        member do
          get :authorize
          get :callback
          delete :disconnect
        end
      end
    end
  end
end
```

---

## Phase 10: I18n Translations

Create complete translation files for ES, EN, PT, and FR in:
- `config/locales/schedulable.es.yml`
- `config/locales/schedulable.en.yml`
- `config/locales/schedulable.pt.yml`
- `config/locales/schedulable.fr.yml`

Include translations for:
- All UI text
- Error messages
- Email templates
- Validation messages
- Flash messages

---

## Phase 11: Testing

### 11.1 Model Specs

Create RSpec tests for all models covering:
- Validations
- Associations
- Scopes
- Instance methods
- Class methods

### 11.2 Service Specs

Test all services:
- AvailabilityChecker
- Payment services (Stripe, Culqi)
- Calendar services (Google, Outlook)

### 11.3 Controller Specs

Test all controller actions:
- Public booking flow
- Admin CRUD operations
- Authorization

### 11.4 Integration Tests

- Complete booking flow
- Payment processing
- Cancellation/rescheduling
- Calendar sync

---

## Phase 12: Documentation

### 12.1 README

Create comprehensive README with:
- Installation instructions
- Configuration guide
- Usage examples
- API documentation

### 12.2 CHANGELOG

Maintain version history

### 12.3 Contributing Guide

Guidelines for contributors

---

## Implementation Order

1. **Phase 1**: Initial Rails setup (1 day)
2. **Phase 2**: Database schema and migrations (2 days)
3. **Phase 3**: Models (3 days)
4. **Phase 4**: Services (3 days)
5. **Phase 5**: Controllers (2 days)
6. **Phase 6**: Views (3 days)
7. **Phase 7**: JavaScript (2 days)
8. **Phase 8**: Background jobs (1 day)
9. **Phase 9**: Routes (1 day)
10. **Phase 10**: I18n (1 day)
11. **Phase 11**: Testing (4 days)
12. **Phase 12**: Documentation (2 days)

**Total estimated time**: 25 days

---

## Success Criteria

- [ ] Multi-tenant organization structure working
- [ ] Individual member schedules functional
- [ ] Public booking flow complete
- [ ] Custom questions working
- [ ] Both payment gateways integrated (Stripe + Culqi)
- [ ] Pay-now and pay-later options working
- [ ] Client cancellation/rescheduling functional
- [ ] Google Calendar integration working
- [ ] Outlook Calendar integration working
- [ ] Multi-language support working (ES, EN, PT, FR)
- [ ] Multi-currency support working (PEN, USD, EUR, GBP)
- [ ] Email notifications sending
- [ ] All tests passing
- [ ] Documentation complete