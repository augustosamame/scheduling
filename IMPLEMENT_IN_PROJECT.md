# Implementing the Scheduling Engine in Your Rails Project

This guide shows you how to integrate the Scheduling engine into your existing Rails application.

## Prerequisites

- Rails 8.0+ application
- PostgreSQL database
- **ActiveStorage configured** (for payment screenshot uploads)
- User model (or ability to create one)
- Ruby 3.3.4+ (recommended)

---

## 📦 Step 1: Add the Gem

Add to your `Gemfile`:

```ruby
# Option 1: From Git Repository - Latest Version (Recommended)
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git'

# Option 2: From Git Repository - Specific Version Tag
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git', tag: 'v0.2.0'

# Option 3: From Git Repository - Specific Branch
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git', branch: 'main'

# Option 4: From Git Repository - Specific Commit
gem 'scheduling', git: 'https://github.com/augustosamame/scheduling.git', ref: 'abc1234'

# Option 5: From Local Path (for development/testing only)
gem 'scheduling', path: '../scheduling'

# Option 6: From RubyGems (when published)
# gem 'scheduling', '~> 0.2.0'
```

**Then install:**

```bash
bundle install
```

**If you encounter git-related bundler issues:**

```bash
# Try clearing bundler cache
bundle config --delete git.allow_insecure
bundle install

# Or force HTTPS for git
bundle config set --local git.allow_insecure true
bundle install
```

**Verify the installation:**

```bash
bundle info scheduling
```

Expected output:
```
* scheduling (0.2.0)
  Summary: Multi-tenant appointment scheduling engine
  Homepage: https://github.com/augustosamame/scheduling
  Source Code: https://github.com/augustosamame/scheduling.git
  Path: /path/to/gems/bundler/gems/scheduling-xxxxx
```

**Troubleshooting:**

If you see "Could not find gem 'scheduling'":
- Verify the git repository URL is correct
- Ensure you have network access to GitHub
- Try using SSH instead of HTTPS: `git: 'git@github.com:augustosamame/scheduling.git'`
- Check if you need to authenticate with GitHub

---

## 👤 Step 2: Ensure User Model Has Required Attributes

The engine requires your `User` model to have these attributes:

### Required Fields:
- `first_name` (string)
- `last_name` (string)
- `email` (string)
- `title` (string) - Professional title
- `bio` (text) - Professional biography

### Add Missing Fields

If you don't have these fields, create a migration:

```bash
rails generate migration AddSchedulingFieldsToUsers first_name:string last_name:string title:string bio:text
```

Or if you already have some fields:

```ruby
# db/migrate/XXXXXX_add_scheduling_fields_to_users.rb
class AddSchedulingFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string unless column_exists?(:users, :first_name)
    add_column :users, :last_name, :string unless column_exists?(:users, :last_name)
    add_column :users, :title, :string unless column_exists?(:users, :title)
    add_column :users, :bio, :text unless column_exists?(:users, :bio)

    # Email usually exists from Devise/authentication, but add if needed:
    # add_column :users, :email, :string unless column_exists?(:users, :email)
  end
end
```

Run the migration:

```bash
rails db:migrate
```

### Update User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :scheduling_members, class_name: 'Scheduling::Member', dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
```

---

## 📎 Step 3: Set Up ActiveStorage

The engine uses ActiveStorage to store payment screenshots uploaded by staff when manually marking bookings as paid.

**If ActiveStorage is not already configured in your app:**

```bash
# For Rails 7+
bin/rails active_storage:install
bin/rails db:migrate

# For Rails 8+ (if the above doesn't work)
# Manually create the migration:
bin/rails generate migration CreateActiveStorageTables
```

If using the manual approach, add this to your migration file:

```ruby
# db/migrate/XXXXXX_create_active_storage_tables.rb
class CreateActiveStorageTables < ActiveRecord::Migration[8.0]
  def change
    # Use Active Record's configured type for primary and foreign keys
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :active_storage_blobs, id: primary_key_type do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false
      else
        t.datetime :created_at, null: false
      end

      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments, id: primary_key_type do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false, type: foreign_key_type
      t.references :blob,     null: false, type: foreign_key_type

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false
      else
        t.datetime :created_at, null: false
      end

      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records, id: primary_key_type do |t|
      t.belongs_to :blob, null: false, index: false, type: foreign_key_type
      t.string :variation_digest, null: false

      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end

  private
    def primary_and_foreign_key_types
      config = Rails.configuration.generators
      setting = config.options[config.orm][:primary_key_type]
      primary_key_type = setting || :primary_key
      foreign_key_type = setting || :bigint
      [primary_key_type, foreign_key_type]
    end
end
```

Then run:

```bash
bin/rails db:migrate
```

**Configure storage service** (config/storage.yml):

For development/test (using local disk storage):

```yaml
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

For production (using AWS S3, Azure, or GCS):

```yaml
# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: us-east-1
  bucket: your-bucket-name
```

**Set the default service** in your environment configs:

```ruby
# config/environments/development.rb
config.active_storage.service = :local

# config/environments/production.rb
config.active_storage.service = :amazon  # or :local, :google, :azure
```

**Note:** ActiveStorage is automatically included in Rails 7+, so you don't need to add any gems.

---

## 🗄️ Step 4: Install Engine Migrations

Copy the engine's migrations to your app:

```bash
rails scheduling:install:migrations
```

This creates 7 migration files in `db/migrate/`:
- `create_scheduling_organizations`
- `create_scheduling_event_types`
- `create_scheduling_schedules`
- `create_scheduling_bookings`
- `create_scheduling_booking_questions`
- `create_scheduling_payments`
- `create_scheduling_calendar_connections`

Run the migrations:

```bash
rails db:migrate
```

---

## 🔐 Step 5: Configure Environment Variables

**IMPORTANT:** Environment variables are set in your **host application**, not in the engine. The engine reads these values at runtime.

### Where to Set ENV Variables

**Option 1: Using .env file (recommended for development)**

Create or edit `.env` in your host app root:

```bash
# .env (in your main Rails app root, NOT in the engine)

# ========================================
# Application Settings (Required)
# ========================================
APP_URL=http://localhost:3000  # Your app's base URL (used for booking confirmation links)
APP_DOMAIN=localhost:3000      # Domain for email links

# ========================================
# Email Configuration (Required for notifications)
# ========================================
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=yourapp.com
SMTP_USERNAME=notifications@yourapp.com
SMTP_PASSWORD=your-app-specific-password

# ========================================
# Payment Integration - Stripe (Optional)
# ========================================
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ========================================
# Payment Integration - Culqi/Peru (Optional)
# ========================================
CULQI_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CULQI_PUBLIC_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ========================================
# Calendar Integration - Google (Optional)
# ========================================
GOOGLE_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ========================================
# Calendar Integration - Microsoft/Outlook (Optional)
# ========================================
MICROSOFT_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MICROSOFT_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ========================================
# SMS/WhatsApp Integration - Twilio (Optional)
# ========================================
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1234567890
TWILIO_WHATSAPP_NUMBER=+14155238886
```

**Add to your Gemfile:**
```ruby
gem 'dotenv-rails', groups: [:development, :test]
```

**Add to .gitignore:**
```
.env
.env.local
```

**Option 2: Using Rails Credentials (recommended for production)**

```bash
# Edit encrypted credentials
EDITOR="code --wait" rails credentials:edit

# Or for specific environment
EDITOR="code --wait" rails credentials:edit --environment production
```

Add to credentials file:
```yaml
stripe:
  secret_key: sk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  publishable_key: pk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

culqi:
  secret_key: sk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  public_key: pk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

google_calendar:
  client_id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
  client_secret: GOCSPX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

microsoft:
  client_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  client_secret: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

app_url: https://yourapp.com
```

Then access in initializer:
```ruby
# config/initializers/scheduling.rb
config.stripe_secret_key = Rails.application.credentials.dig(:stripe, :secret_key)
config.stripe_publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key)
# etc.
```

### Complete ENV Variables Reference

| Variable | Required? | Purpose | Example |
|----------|-----------|---------|---------|
| **Application** ||||
| `APP_URL` | **Yes** | Base URL for booking confirmation links | `http://localhost:3000` |
| `APP_DOMAIN` | **Yes** (for emails) | Domain for email links | `localhost:3000` or `app.com` |
| **Email/SMTP** ||||
| `SMTP_ADDRESS` | **Yes** (for emails) | SMTP server address | `smtp.gmail.com` |
| `SMTP_PORT` | **Yes** (for emails) | SMTP server port | `587` |
| `SMTP_DOMAIN` | **Yes** (for emails) | Your app's domain | `yourapp.com` |
| `SMTP_USERNAME` | **Yes** (for emails) | SMTP username/email | `notifications@yourapp.com` |
| `SMTP_PASSWORD` | **Yes** (for emails) | SMTP password | App-specific password |
| **Payment - Stripe** ||||
| `STRIPE_SECRET_KEY` | Only if using Stripe | Stripe API secret key | `sk_test_...` or `sk_live_...` |
| `STRIPE_PUBLISHABLE_KEY` | Only if using Stripe | Stripe public key (frontend) | `pk_test_...` or `pk_live_...` |
| **Payment - Culqi** ||||
| `CULQI_SECRET_KEY` | Only if using Culqi | Culqi API secret (Peru) | `sk_test_...` or `sk_live_...` |
| `CULQI_PUBLIC_KEY` | Only if using Culqi | Culqi public key (Peru) | `pk_test_...` or `pk_live_...` |
| **Calendar - Google** ||||
| `GOOGLE_CLIENT_ID` | Only if using Google Cal | OAuth 2.0 client ID | `xxx.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | Only if using Google Cal | OAuth 2.0 client secret | `GOCSPX-xxx` |
| **Calendar - Microsoft** ||||
| `MICROSOFT_CLIENT_ID` | Only if using Outlook | Azure AD application ID | `xxxxxxxx-xxxx-xxxx-xxxx` |
| `MICROSOFT_CLIENT_SECRET` | Only if using Outlook | Azure AD client secret | `xxx~xxx` |
| **SMS/WhatsApp - Twilio** ||||
| `TWILIO_ACCOUNT_SID` | Only if using Twilio | Twilio account SID | `ACxxxxx` |
| `TWILIO_AUTH_TOKEN` | Only if using Twilio | Twilio auth token | `xxxxx` |
| `TWILIO_PHONE_NUMBER` | Only if using Twilio SMS | Twilio SMS phone number | `+1234567890` |
| `TWILIO_WHATSAPP_NUMBER` | Only if using Twilio WhatsApp | Twilio WhatsApp number | `+14155238886` or `whatsapp:+14155238886` |

### Getting API Keys

**Stripe:**
1. Sign up at https://stripe.com
2. Go to Developers → API Keys
3. Copy "Secret key" and "Publishable key"
4. Use test keys for development (`sk_test_...` and `pk_test_...`)

**Culqi (Peru):**
1. Sign up at https://culqi.com
2. Go to Desarrollo → API Keys
3. Copy keys for test/production

**Google Calendar:**
1. Go to https://console.cloud.google.com
2. Create a new project
3. Enable Google Calendar API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URI: `http://localhost:3000/book/calendar_connections/google_callback`

**Microsoft/Outlook:**
1. Go to https://portal.azure.com
2. Register a new application
3. Add redirect URI: `http://localhost:3000/book/calendar_connections/outlook_callback`
4. Create a client secret
5. Grant Calendar permissions

### Verify ENV Variables

```ruby
# In rails console
ENV['STRIPE_SECRET_KEY']  # Should show your key
ENV['APP_URL']            # Should show your app URL

# Or check if payment/calendar features are available
Scheduling.configuration.stripe_available?
Scheduling.configuration.google_calendar_enabled?
```

---

## 🔧 Step 6: Create Initializer (**Required**)

Create `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  # ========================================
  # Organization Settings (REQUIRED)
  # ========================================
  config.organization_name = 'Your Company Name'
  config.organization_slug = 'your-company'  # URL-friendly, no spaces
  config.organization_timezone = 'America/New_York'  # Your timezone
  config.organization_currency = 'USD'
  config.organization_locale = 'en'

  # ========================================
  # Auto-Sync Settings (REQUIRED)
  # ========================================
  # Automatically create Scheduling::Member when Users are created/updated
  config.auto_create_members = true
  config.sync_member_on_user_update = true

  # Automatically create default schedule and event type for new members
  config.auto_create_default_schedule = true     # Creates Mon-Fri 9am-5pm schedule
  config.auto_create_default_event_type = true   # Creates "General Appointment" event type

  # Fallback names when User doesn't have location/team associations
  config.default_location_name = 'Main Office'
  config.default_team_name = 'Default Team'

  # ========================================
  # Optional Settings
  # ========================================
  # Locale settings
  config.default_locale = :en
  config.available_locales = [:en, :es, :pt, :fr]
  config.detect_locale_from_browser = true

  # Currency settings
  config.default_currency = 'USD'
  config.available_currencies = ['USD', 'EUR', 'GBP', 'PEN']

  # Booking policies (defaults)
  config.default_cancellation_hours = 24
  config.default_rescheduling_hours = 24
  config.default_minimum_notice_hours = 2

  # Notifications
  config.send_confirmation_emails = true
  config.send_reminder_emails = false
  config.enable_sms_notifications = false

  # Payment providers (optional - install gems separately)
  config.payment_providers = [:stripe]  # or [:stripe, :culqi]

  # Calendar integrations (optional - need OAuth setup)
  config.enable_google_calendar = false
  config.enable_outlook_calendar = false
end
```

**Important Configuration Notes:**

- `organization_name` and `organization_slug` are **required** for auto-sync to work
- `organization_slug` must be URL-friendly (lowercase, no spaces, use hyphens)
- `organization_timezone` should match your business timezone
- Set `auto_create_members = true` to enable automatic Member creation
- Adjust default policies based on your business requirements

---

## 🛣️ Step 7: Mount the Engine Routes

Add to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Your main app routes
  root 'home#index'
  resources :users
  get '/dashboard', to: 'dashboard#show'

  # Mount scheduling engine at a clear subpath
  mount Scheduling::Engine => "/book"  # Recommended!
end
```

### Mounting Options

⚠️ **Important:** The engine has greedy routes like `/:organization_slug/:member_slug` that will conflict with your main app routes if mounted at root!

**Option 1: Subpath (Recommended for most apps)**
```ruby
mount Scheduling::Engine => "/book"
# or "/appointments", "/schedule", "/cal", etc.
```
- ✅ URLs: `/book/test-clinic/dr-maria-rodriguez`
- ✅ No route conflicts with main app
- ✅ Clear separation of concerns
- ✅ Recommended for production apps

**Option 2: Subdomain (Best for scalability)**
```ruby
# Requires subdomain DNS setup
constraints subdomain: 'book' do
  mount Scheduling::Engine => "/"
end
```
- ✅ URLs: `https://book.example.com/test-clinic/dr-maria-rodriguez`
- ✅ Cleanest URLs
- ✅ Complete route isolation
- ✅ Can scale to per-organization subdomains
- ⚠️  Requires DNS/SSL configuration

**Option 3: Root mounting (Only for dedicated booking apps)**
```ruby
mount Scheduling::Engine => "/"
```
- ⚠️  **Only use if your app has NO other routes**
- ⚠️  Will conflict with routes like `/dashboard`, `/users/:id`, etc.
- ✅ Good for dummy/test apps or single-purpose booking sites

### Available Routes

When mounted at `/book`:
- Organization page: `/book/:org_slug` (all bookable members)
- Member's event types: `/book/:org_slug/:member_slug`
- Booking form: `/book/:org_slug/:member_slug/:event_slug/book`
- Confirmation: `/book/bookings/:uid`
- Cancel: `/book/bookings/:token/cancel`
- Reschedule: `/book/bookings/:token/reschedule`

### Understanding URL Parameters

**`:org_slug` - Organization Slug:**
- Comes from the `Organization` record in the database
- Created automatically from your configuration when first User is created
- Example: If you configure `organization_slug: 'your-company'`, the URL will be `/book/your-company/...`

```ruby
# Configuration (config/initializers/scheduling.rb)
config.organization_slug = 'your-company'  # ← This value
config.organization_name = 'Your Company Name'

# Creates this database record (automatically):
Organization.find_or_create_by!(slug: 'your-company') do |org|
  org.name = 'Your Company Name'
end

# Results in URLs like:
# /book/your-company/dr-sarah-johnson
```

**`:member_slug` - Member Booking Slug:**
- Automatically generated from user's name when Member is created
- Stored in `Member.booking_slug` field
- Example: "Dr. Sarah Johnson" → `dr-sarah-johnson`

**`:event_slug` - Event Type Slug:**
- Set when creating EventType (or auto-generated from title)
- Example: "Initial Consultation" → `initial-consultation`

**Complete URL Example:**
```
https://yourapp.com/book/your-company/dr-sarah-johnson/initial-consultation/book
                        └─────┬──────┘ └────────┬────────┘ └─────────┬─────────┘
                          org_slug         member_slug           event_slug
```

---

## ✅ Step 8: Verify Installation

Restart your Rails server and test in console:

```bash
rails console
```

```ruby
# Check configuration
Scheduling.configuration.organization_name
# => "Your Company Name"

Scheduling.configuration.auto_create_members
# => true

# Check if UserExtensions is included
User.included_modules.include?(Scheduling::UserExtensions)
# => true (if config.auto_create_members is true)
```

---

## 🎯 Step 9: Sync Users to Create Members

### For Apps with NO Existing Users

If this is a new app, just create users normally and Members will auto-create:

```ruby
user = User.create!(
  first_name: "Dr. Sarah",
  last_name: "Johnson",
  email: "sarah@example.com",
  title: "General Practitioner",
  bio: "Board-certified family medicine physician"
)

# Member is automatically created via callback!
member = Scheduling::Member.find_by(user: user)

puts "Member created: #{member.present? ? 'YES! ✅' : 'NO ❌'}"
puts "Booking slug: #{member.booking_slug}" if member
# => "dr-sarah-johnson"

puts "Organization: #{Scheduling::Organization.first.name}"
# => "Your Company Name"
```

### For Apps with EXISTING Users (IMPORTANT!)

**⚠️  If you're installing this gem in an app that already has users**, you need to sync them:

```bash
# First, check how many users need syncing
rails scheduling:stats

# Example output:
# 👥 Users:
#    Total users: 150
#    Users with Members: 0
#    Users without Members: 150

# Sync all users without Members
rails scheduling:sync_existing_users

# This will:
# 1. Find all users without Member records
# 2. Ask for confirmation
# 3. Sync each user using MemberSyncService
# 4. Show progress and any errors
# 5. Display summary statistics
```

**Example Output:**

```
🔄 Starting sync of existing users to Scheduling::Members...
============================================================
📊 Statistics:
   Total users: 150
   Users without Members: 150
   Users with Members: 0

⚠️  This will create 150 new Member records.
   Continue? (y/n)
y

🚀 Syncing users...

✅ [1/150] Synced: dr.smith@clinic.com → Member #1 (dr-john-smith)
✅ [2/150] Synced: dr.jones@clinic.com → Member #2 (dr-mary-jones)
...
✅ [150/150] Synced: dr.garcia@clinic.com → Member #150 (dr-carlos-garcia)

============================================================
🎉 Sync Complete!

📊 Results:
   Successfully synced: 150
   Errors: 0
   Total processed: 150

📈 Final Statistics:
   Total Members: 150
   Total Organizations: 1
   Total Locations: 1
   Total Teams: 1

✅ Done!
```

**Sync a Single User:**

```bash
rails scheduling:sync_user[sarah@example.com]
```

**What Happens During Sync:**

1. ✅ User validated (has required fields)
2. ✅ Organization auto-created (from config, if doesn't exist)
3. ✅ Location auto-created (from user.location or default: "Main Office")
4. ✅ Team auto-created (from user.team or default: "Default Team")
5. ✅ Member auto-created and linked to User
6. ✅ `booking_slug` generated from user's name
7. ✅ **Default schedule auto-created** (Monday-Friday, 9 AM - 5 PM) *if enabled*
8. ✅ **Default event type auto-created** ("General Appointment", 30 min, free) *if enabled*

**Members are immediately ready to accept bookings!** (if default schedule/event type creation is enabled)

---

## 📧 Step 10: Configure Email Delivery (Required for Notifications)

**IMPORTANT:** The engine has its own mailer (`Scheduling::BookingMailer`) but **uses your host app's ActionMailer configuration** for actually sending emails.

### Setup Host App Email Configuration

The engine will send:
- Booking confirmation emails (with .ics calendar attachment)
- Booking cancellation emails
- Booking reschedule emails
- Booking reminder emails (if enabled)

**Configure ActionMailer in your host app:**

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'example.com',
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  domain: ENV['SMTP_DOMAIN'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { host: ENV['APP_DOMAIN'] }
```

**Add SMTP ENV variables to .env:**

```bash
# Email Configuration (for ActionMailer)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=yourapp.com
SMTP_USERNAME=notifications@yourapp.com
SMTP_PASSWORD=your-app-specific-password
APP_DOMAIN=yourapp.com  # Used for email links
```

**Configure the engine's mailer from address:**

```ruby
# config/initializers/scheduling.rb
Scheduling.configure do |config|
  # ... other config ...

  # Email settings
  config.mailer_from = 'bookings@yourcompany.com'  # From address for booking emails
  config.send_confirmation_emails = true           # Send confirmation emails
  config.send_reminder_emails = false              # Send reminder emails before appointments
  config.reminder_hours_before = 24                # How many hours before to send reminder
end
```

### Email Service Providers

**Gmail (Development):**
1. Enable 2-factor authentication
2. Generate an app-specific password
3. Use that password in SMTP_PASSWORD

**SendGrid (Production):**
```ruby
config.action_mailer.smtp_settings = {
  address: 'smtp.sendgrid.net',
  port: 587,
  domain: ENV['SMTP_DOMAIN'],
  user_name: 'apikey',
  password: ENV['SENDGRID_API_KEY'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

**Mailgun:**
```ruby
config.action_mailer.smtp_settings = {
  address: 'smtp.mailgun.org',
  port: 587,
  domain: ENV['MAILGUN_DOMAIN'],
  user_name: ENV['MAILGUN_SMTP_LOGIN'],
  password: ENV['MAILGUN_SMTP_PASSWORD'],
  authentication: 'plain',
}
```

**AWS SES:**
```ruby
config.action_mailer.delivery_method = :aws_sdk
# Requires: gem 'aws-sdk-rails'
```

### Test Email Configuration

```bash
rails console
```

```ruby
# Send a test booking confirmation
booking = Scheduling::Booking.first
Scheduling::BookingMailer.confirmation_email(booking.id).deliver_now

# Check if it was sent
ActionMailer::Base.deliveries.last
```

### Email Views and Customization

The engine includes default email templates at:
- `app/views/scheduling/booking_mailer/confirmation_email.html.erb`
- `app/views/scheduling/booking_mailer/cancellation_email.html.erb`
- `app/views/scheduling/booking_mailer/reschedule_email.html.erb`
- `app/views/scheduling/booking_mailer/reminder_email.html.erb`

**To customize email templates in your host app:**

```bash
# Copy engine views to your app
mkdir -p app/views/scheduling/booking_mailer
cp $(bundle show scheduling)/app/views/scheduling/booking_mailer/* app/views/scheduling/booking_mailer/
```

Then edit the templates in your app - they will override the engine's templates.

---

## 📱 SMS and WhatsApp Notifications (Twilio Integration)

The engine includes **complete Twilio integration** for SMS and WhatsApp notifications!

### What's Included:

- ✅ SMS booking confirmations
- ✅ SMS cancellation notifications
- ✅ SMS reschedule notifications
- ✅ SMS appointment reminders
- ✅ WhatsApp booking confirmations (with rich formatting)
- ✅ WhatsApp cancellation notifications
- ✅ WhatsApp reschedule notifications
- ✅ WhatsApp appointment reminders (with rich formatting)
- ✅ Multi-language support (ES, EN, PT, FR)
- ✅ Phone number validation
- ✅ Automatic retry on failure
- ✅ Background job processing

### Setup Instructions

**Step 1: Install Twilio Gem**

```ruby
# Gemfile
gem 'twilio-ruby', '~> 6.0'
```

```bash
bundle install
```

**Step 2: Get Twilio Credentials**

1. Sign up at https://www.twilio.com
2. Go to Console Dashboard
3. Copy your **Account SID** and **Auth Token**
4. Get a phone number:
   - For SMS: Get a Twilio phone number
   - For WhatsApp: Request WhatsApp sandbox access (development) or WhatsApp Business approval (production)

**Step 3: Add ENV Variables**

```bash
# .env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1234567890  # Your Twilio SMS number
TWILIO_WHATSAPP_NUMBER=+14155238886  # Twilio WhatsApp number (sandbox or approved)
```

**Step 4: Enable in Configuration**

```ruby
# config/initializers/scheduling.rb
Scheduling.configure do |config|
  # ... other config ...

  # Enable SMS and WhatsApp notifications
  config.enable_sms_notifications = true
  config.enable_whatsapp_notifications = true

  # Optional: Set credentials in config instead of ENV (not recommended for production)
  # config.twilio_account_sid = 'ACxxxxx'
  # config.twilio_auth_token = 'xxxxx'
  # config.twilio_phone_number = '+1234567890'
  # config.twilio_whatsapp_number = '+14155238886'
end
```

**Step 5: Ensure Clients Have Phone Numbers**

The engine automatically sends notifications if `client.phone` is present:

```ruby
# When creating a booking, make sure client has phone
client = Scheduling::Client.create!(
  organization: org,
  first_name: "John",
  last_name: "Doe",
  email: "john@example.com",
  phone: "+15551234567"  # ← Must include country code (+1 for US)
)
```

**Phone Number Format:**
- Must include country code (e.g., +1 for US, +51 for Peru, +52 for Mexico)
- Can have spaces/dashes: "+1 555-123-4567" or "+15551234567" (both work)
- WhatsApp uses same phone number as SMS

### How It Works

**Automatic Notifications:**

When a booking is created, cancelled, or rescheduled, the engine automatically:
1. Sends email notification (if enabled)
2. Sends SMS notification (if enabled and phone present)
3. Sends WhatsApp notification (if enabled and phone present)

```ruby
# Create a booking - automatically triggers notifications
booking = event_type.bookings.create!(
  client: client,
  member: member,
  start_time: time,
  timezone: 'America/Lima'
)
# ✅ Email sent (if enabled)
# ✅ SMS sent (if enabled and client.phone present)
# ✅ WhatsApp sent (if enabled and client.phone present)

# Cancel booking - automatically notifies client
booking.cancel!(reason: "Doctor unavailable", initiated_by: 'admin')
# ✅ Cancellation email sent
# ✅ Cancellation SMS sent
# ✅ Cancellation WhatsApp sent

# Reschedule - automatically notifies with new time
new_booking = booking.reschedule_to!(new_time, reason: "Client request")
# ✅ Reschedule email sent
# ✅ Reschedule SMS sent
# ✅ Reschedule WhatsApp sent
```

**Manual Notifications:**

You can also send notifications manually:

```ruby
booking = Scheduling::Booking.first

# Send SMS
booking.send_confirmation_sms
booking.send_cancellation_sms
booking.send_reschedule_sms
booking.send_reminder_sms

# Send WhatsApp
booking.send_confirmation_whatsapp
booking.send_reminder_whatsapp
```

### WhatsApp Setup

**Development (Sandbox):**
1. Go to Twilio Console → Messaging → Try it out → Try WhatsApp
2. Follow instructions to join sandbox (send code via WhatsApp)
3. Use sandbox number: `+14155238886` (or your region's sandbox number)
4. Add to `.env`: `TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886`

**Production:**
1. Apply for WhatsApp Business approval at https://www.twilio.com/console/sms/whatsapp/senders
2. Wait for approval (can take a few days)
3. Once approved, use your WhatsApp-enabled number

**Note:** WhatsApp requires the number format: `whatsapp:+1234567890` (engine handles this automatically)

### Testing SMS/WhatsApp

**Test in Console:**

```bash
rails console
```

```ruby
# Find a booking with client that has phone number
booking = Scheduling::Booking.first
client = booking.client
client.update!(phone: '+15551234567')  # Add test phone number

# Test SMS
service = Scheduling::TwilioNotificationService.new(booking)
service.send_sms_confirmation
# => Check your phone for SMS!

# Test WhatsApp
service.send_whatsapp_confirmation
# => Check WhatsApp for message!

# Check if Twilio is configured
Scheduling::TwilioNotificationService.configured?
# => true

# Check specific features
Scheduling.configuration.sms_available?
# => true
Scheduling.configuration.whatsapp_available?
# => true
```

**Test with Background Jobs:**

```ruby
booking = Scheduling::Booking.first
Scheduling::BookingSmsJob.perform_now(booking.id, :confirmation)
Scheduling::BookingWhatsappJob.perform_now(booking.id, :confirmation)
```

### Message Templates

**SMS Messages** (plain text):
```
Confirmation:
"Hello John! Your appointment with Dr. Smith for General Consultation
is confirmed for Monday, May 15, 2024 at 02:00 PM. Location: Main Office.
Cancel: https://app.com/bookings/abc123/cancel"

Reminder:
"Reminder: Your appointment with Dr. Smith for General Consultation
is on Monday, May 15, 2024 at 02:00 PM. Location: Main Office"
```

**WhatsApp Messages** (rich formatting):
```
*Booking Confirmed* ✅

Hello John! Your appointment has been confirmed.

*Professional:* Dr. Smith
*Service:* General Consultation
*Date:* Monday, May 15, 2024
*Time:* 02:00 PM
*Location:* Main Office

Need to cancel? https://app.com/bookings/abc123/cancel
```

### Customization

**Custom Message Templates:**

Override the service methods in your app:

```ruby
# app/services/custom_twilio_service.rb
class CustomTwilioService < Scheduling::TwilioNotificationService
  private

  def confirmation_message
    "¡Hola! Tu cita está confirmada para el #{@booking.start_time.strftime('%d/%m/%Y')} ⏰"
  end
end

# Use custom service
CustomTwilioService.new(booking).send_sms_confirmation
```

### Troubleshooting

**SMS/WhatsApp not sending:**

```ruby
# Check if Twilio is configured
Scheduling::TwilioNotificationService.configured?
# => Should return true

# Check configuration
ENV['TWILIO_ACCOUNT_SID']
ENV['TWILIO_AUTH_TOKEN']
ENV['TWILIO_PHONE_NUMBER']

# Check if features are enabled
Scheduling.configuration.enable_sms_notifications
Scheduling.configuration.enable_whatsapp_notifications

# Check client has phone
booking.client.phone.present?
# => Should return true

# Check logs for errors
tail -f log/development.log | grep -i twilio
```

**Invalid phone number errors:**
- Ensure phone includes country code: `+15551234567` (not `5551234567`)
- Remove special characters: `+1 555-123-4567` → auto-converted to `+15551234567`

**WhatsApp not working:**
- Verify you've joined the sandbox (development)
- Check WhatsApp number format: `whatsapp:+14155238886`
- Ensure recipient's phone is registered with WhatsApp

**Twilio API errors:**
- Check account balance
- Verify phone numbers are valid
- Check Twilio console for error details

### Costs

**Twilio Pricing (approximate):**
- SMS: ~$0.0075 per message (US)
- WhatsApp: ~$0.005 per message (conversation-based pricing)
- Phone number: ~$1/month

**Free trial:**
- Twilio provides free trial credits
- Can only send to verified phone numbers during trial

### Production Checklist

- [ ] Twilio account upgraded from trial
- [ ] Production credentials in Rails credentials (not .env)
- [ ] WhatsApp Business approved (if using WhatsApp)
- [ ] Phone numbers formatted correctly in database
- [ ] Monitoring setup for failed messages
- [ ] Background job queue configured (Solid Queue, Sidekiq, etc.)
- [ ] Error notifications configured
- [ ] Tested in staging environment

---

## 🌱 Seed Data - No Manual Seeding Required!

**IMPORTANT:** You do **NOT** need to manually seed any data. Everything is created automatically!

### What Gets Created Automatically:

When you create the first User (or run `rails scheduling:sync_existing_users`):

1. ✅ **Organization** - Created from `config.organization_name` and `config.organization_slug`
2. ✅ **Location** - Created from `user.location` (if exists) or `config.default_location_name`
3. ✅ **Team** - Created from `user.team` (if exists) or `config.default_team_name`
4. ✅ **Member** - Created and linked to User
5. ✅ **Default Schedule** - Mon-Fri 9am-5pm (if `auto_create_default_schedule = true`)
6. ✅ **Default Event Type** - "General Appointment" (if `auto_create_default_event_type = true`)

### How It Works:

```ruby
# In app/services/scheduling/member_sync_service.rb
def sync
  organization = ensure_organization  # Find or create
  location = ensure_location(organization)  # Find or create
  team = ensure_team(location)  # Find or create
  member = ensure_member(team)  # Find or create

  # If auto_create_default_schedule enabled:
  create_default_schedule(member)  # Mon-Fri 9am-5pm

  # If auto_create_default_event_type enabled:
  create_default_event_type(member)  # 30min appointment, free
end
```

### Verify Auto-Creation:

```ruby
# Create a user
user = User.create!(
  first_name: "Dr. Sarah",
  last_name: "Johnson",
  email: "sarah@example.com",
  title: "General Practitioner",
  bio: "Board-certified family physician"
)

# Check what was created automatically
org = Scheduling::Organization.first
# => #<Scheduling::Organization name: "Your Company Name", slug: "your-company">

location = org.locations.first
# => #<Scheduling::Location name: "Main Office">

team = location.teams.first
# => #<Scheduling::Team name: "Default Team">

member = Scheduling::Member.find_by(user: user)
# => #<Scheduling::Member booking_slug: "dr-sarah-johnson">

member.schedules.count
# => 1 (if auto_create_default_schedule enabled)

member.event_types.count
# => 1 (if auto_create_default_event_type enabled)
```

### Manual Seed File (Optional)

If you want to create sample data for development:

```ruby
# db/seeds.rb

# Users are created, Members auto-sync
users_data = [
  { first_name: "Dr. Sarah", last_name: "Johnson", email: "sarah@clinic.com", title: "GP" },
  { first_name: "Dr. Mike", last_name: "Chen", email: "mike@clinic.com", title: "Cardiologist" }
]

users_data.each do |data|
  User.find_or_create_by!(email: data[:email]) do |u|
    u.assign_attributes(data)
    u.bio = "Experienced #{data[:title]}"
  end
end

puts "✅ Created #{User.count} users"
puts "✅ Auto-created #{Scheduling::Member.count} members"
puts "✅ Auto-created #{Scheduling::Organization.count} organizations"
puts "✅ Auto-created #{Scheduling::Location.count} locations"
puts "✅ Auto-created #{Scheduling::Team.count} teams"
```

**No database seeds needed!** Just configure the initializer and create users.

---

## 📅 Step 11: Customize Schedules (Optional)

**If you enabled `auto_create_default_schedule = true`**, members already have a default Monday-Friday 9am-5pm schedule. You can customize it or add additional schedules:

```ruby
member = Scheduling::Member.first

# Create a schedule (Monday-Friday, 9 AM - 5 PM)
schedule = member.schedules.create!(
  name: "Office Hours",
  timezone: "America/New_York",
  is_default: true
)

# Add availability for each weekday
(1..5).each do |day|  # 1 = Monday, 5 = Friday
  schedule.availabilities.create!(
    day_of_week: day,
    start_time: "09:00",
    end_time: "17:00"
  )
end

puts "Schedule created with #{schedule.availabilities.count} days"
```

---

## 🎫 Step 12: Customize Event Types (Optional)

**If you enabled `auto_create_default_event_type = true`**, members already have a "General Appointment" event type. You can customize it or add more event types:

```ruby
member = Scheduling::Member.first

event_type = member.event_types.create!(
  title: "Initial Consultation",
  slug: "initial-consultation",
  description: "First-time patient consultation",
  location_type: "in_person",  # or "video", "phone"
  location_details: "Main Office, Room 101",
  duration_minutes: 30,
  buffer_before_minutes: 5,
  buffer_after_minutes: 10,
  minimum_notice_hours: 24,  # Book at least 24hrs in advance
  maximum_days_in_future: 90,  # Can book up to 90 days out
  color: "#3b82f6",
  active: true,
  requires_payment: true,
  price_cents: 15000,  # $150.00
  price_currency: "USD",
  payment_required_to_book: false,  # Can pay after booking
  allow_rescheduling: true,
  rescheduling_policy_hours: 24,
  allow_cancellation: true,
  cancellation_policy_hours: 24
)

# Add custom booking questions
event_type.booking_questions.create!(
  label: "What is the reason for your visit?",
  question_type: "textarea",
  required: true,
  position: 1,
  placeholder: "Please describe your symptoms or concerns",
  help_text: "This helps us prepare for your appointment"
)

event_type.booking_questions.create!(
  label: "Do you have any allergies?",
  question_type: "text",
  required: false,
  position: 2,
  placeholder: "List any known allergies"
)

puts "Event type created: #{event_type.title}"
```

---

## 🧪 Step 13: Test Availability

```ruby
member = Scheduling::Member.first
event_type = member.event_types.first

# Check availability
checker = Scheduling::AvailabilityChecker.new(member, event_type)
slots = checker.available_slots(Date.today..(Date.today + 7))

puts "Found #{slots.count} available slots in next 7 days"

# View some slots
slots.first(5).each do |slot|
  puts slot[:start_time].strftime('%A, %B %d at %I:%M %p')
end
```

---

## 🌐 Step 14: Access the Booking Page

Visit in your browser:

```
http://localhost:3000/scheduling/your-company/dr-sarah-johnson
```

You should see the member's booking page with available event types.

To book an appointment:

```
http://localhost:3000/scheduling/your-company/dr-sarah-johnson/initial-consultation/book
```

---

## 🔄 Optional: User Associations (Advanced)

If your User model has `location` or `team` associations, the engine will use them automatically:

```ruby
# Add to User model
class User < ApplicationRecord
  belongs_to :location, optional: true
  belongs_to :team, optional: true
end

# When creating users
location = Location.create!(name: "Downtown Office")
team = Team.create!(name: "Cardiology Department")

user = User.create!(
  first_name: "Dr. John",
  last_name: "Smith",
  email: "john@example.com",
  location: location,
  team: team
)

# Engine will use user.location.name and user.team.name
member = Scheduling::Member.find_by(user: user)
puts member.team.name
# => "Cardiology Department" (from user.team.name)
```

If User doesn't have these associations, the engine falls back to configured defaults.

---

## 💳 Optional: Payment Integration

### Stripe

1. Add to Gemfile:
   ```ruby
   gem 'stripe', '~> 10.0'
   ```

2. Set environment variables:
   ```bash
   # .env or config/credentials.yml
   STRIPE_API_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

3. Enable in initializer:
   ```ruby
   config.payment_providers = [:stripe]
   ```

### Culqi (Peru)

1. Install gem separately (not in RubyGems yet)
2. Set environment variables:
   ```bash
   CULQI_PUBLIC_KEY=pk_test_...
   CULQI_SECRET_KEY=sk_test_...
   ```

3. Enable in initializer:
   ```ruby
   config.payment_providers = [:culqi]
   ```

---

## 📧 Optional: Email Notifications

The engine includes background jobs for notifications, but you need to implement the mailer:

```ruby
# app/mailers/scheduling/booking_mailer.rb
module Scheduling
  class BookingMailer < ApplicationMailer
    def confirmation_email(booking_id)
      @booking = Booking.find(booking_id)
      mail(
        to: @booking.client.email,
        subject: "Booking Confirmation - #{@booking.event_type.title}"
      )
    end

    def cancellation_email(booking_id)
      @booking = Booking.find(booking_id)
      mail(
        to: @booking.client.email,
        subject: "Booking Cancelled"
      )
    end

    def reschedule_email(booking_id)
      @booking = Booking.find(booking_id)
      mail(
        to: @booking.client.email,
        subject: "Booking Rescheduled"
      )
    end
  end
end
```

---

## 🐛 Troubleshooting

### Members Not Auto-Creating

**Check 1:** Verify configuration

```ruby
Scheduling.configuration.auto_create_members
# => Should be true
```

**Check 2:** Verify UserExtensions is loaded

```ruby
User.included_modules.include?(Scheduling::UserExtensions)
# => Should be true
```

**Check 3:** Check logs

```bash
tail -f log/development.log
```

Look for errors like "Failed to sync scheduling member"

**Check 4:** User has required fields

```ruby
user = User.first
user.first_name.present?  # => true
user.last_name.present?   # => true
```

### No Available Slots

**Check 1:** Member has a schedule

```ruby
member.schedules.any?
# => Should be true
```

**Check 2:** Schedule has availabilities

```ruby
member.default_schedule.availabilities.count
# => Should be > 0
```

**Check 3:** Check minimum notice

```ruby
event_type.minimum_notice_hours
# => If this is 24, you need to check slots > 24 hours from now
```

### Route Not Found

Make sure you mounted the engine:

```ruby
# config/routes.rb
mount Scheduling::Engine => "/"  # or "/scheduling" if using a subpath
```

Restart the server after adding routes.

---

## 📊 Seed Data (Optional)

Create `db/seeds.rb` (or add to existing):

```ruby
# Create users - Members will auto-create!
users_data = [
  { first_name: "Dr. Sarah", last_name: "Johnson", email: "sarah@clinic.com", title: "General Practitioner" },
  { first_name: "Dr. Michael", last_name: "Chen", email: "michael@clinic.com", title: "Cardiologist" },
  { first_name: "Dr. Emily", last_name: "Rodriguez", email: "emily@clinic.com", title: "Pediatrician" }
]

users_data.each do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.first_name = data[:first_name]
    u.last_name = data[:last_name]
    u.title = data[:title]
    u.bio = "Experienced #{data[:title].downcase}"
  end

  member = Scheduling::Member.find_by(user: user)

  # Create schedule
  schedule = member.schedules.find_or_create_by!(name: "Office Hours", is_default: true) do |s|
    s.timezone = "America/New_York"
  end

  if schedule.availabilities.empty?
    (1..5).each do |day|
      schedule.availabilities.create!(
        day_of_week: day,
        start_time: "09:00",
        end_time: "17:00"
      )
    end
  end

  # Create event types
  member.event_types.find_or_create_by!(slug: "consultation") do |et|
    et.title = "30-Minute Consultation"
    et.duration_minutes = 30
    et.minimum_notice_hours = 24
    et.maximum_days_in_future = 90
    et.price_cents = 15000
    et.price_currency = "USD"
    et.active = true
  end
end

puts "✅ Seed data created!"
puts "   Users: #{User.count}"
puts "   Members: #{Scheduling::Member.count}"
puts "   Organizations: #{Scheduling::Organization.count}"
```

Run seeds:

```bash
rails db:seed
```

---

## 🚀 Next Steps

1. **Customize views** - The engine provides controllers but you'll want to create your own views
2. **Add authentication** - Protect member/admin areas
3. **Implement mailers** - For booking confirmations
4. **Set up payments** - Configure Stripe/Culqi
5. **Calendar sync** - Set up OAuth for Google/Outlook
6. **Customize policies** - Adjust cancellation/rescheduling rules per event type

---

## 📚 Additional Resources

- **TEST_ENGINE.md** - How to test the engine in isolation
- **CLAUDE.md** - Architecture and development guide
- **DATA_OWNERSHIP.md** - Understanding the delegation pattern
- **README.md** - General overview and features

---

## ✅ Checklist

Before going to production, verify:

- [ ] User model has all required fields (first_name, last_name, email, title, bio)
- [ ] Initializer created with correct organization settings
- [ ] Auto-sync enabled and working (test by creating a user)
- [ ] Routes mounted
- [ ] Schedules created for all members who accept bookings
- [ ] Event types created with correct pricing and policies
- [ ] Booking pages accessible
- [ ] Payment provider configured (if using payments)
- [ ] Email notifications working (if enabled)
- [ ] Tested booking creation, cancellation, and rescheduling
- [ ] Production environment variables set

---

## 🎉 You're Ready!

Your scheduling system is now fully integrated. Users you create will automatically get Member records, and they'll be ready to accept bookings once you set up their schedules and event types.

For questions or issues, check the documentation or create an issue on GitHub.
