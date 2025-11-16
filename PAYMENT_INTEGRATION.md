# Payment Integration Guide

Complete guide for integrating Stripe and Culqi payments with the Scheduling engine.

## Overview

The Scheduling engine supports **three payment modes** per Event Type:

### 1. No Payment (Free Appointments)
- **Mode**: `requires_payment: false`
- **Flow**: Client books → Immediately confirmed → No payment involved
- **Use case**: Free consultations, internal meetings

### 2. Optional Payment
- **Mode**: `requires_payment: true, payment_required_to_book: false`
- **Flow**: Client books → Confirmed → Can pay later via "Pay Now" button
- **Use case**: Services where payment is preferred but not mandatory

### 3. Mandatory Payment
- **Mode**: `requires_payment: true, payment_required_to_book: true`
- **Flow**: Client selects time → Payment required → Confirmed only after payment
- **Use case**: Paid services, deposits, prepaid consultations

---

## Supported Payment Gateways

| Gateway | Regions | Currencies | Status |
|---------|---------|------------|--------|
| **Stripe** | Global | 135+ currencies | ✅ Fully Implemented |
| **Culqi** | Peru, Chile, Mexico | PEN, USD | ✅ Fully Implemented |

---

## Table of Contents

1. [Stripe Setup](#stripe-setup)
2. [Culqi Setup](#culqi-setup)
3. [Culqi Frontend Implementation](#step-7-frontend-implementation)
4. [Configuration](#configuration)
5. [Payment Flows](#payment-flows)
6. [Testing Payments](#testing-payments)
7. [Refunds](#refunds)
8. [Troubleshooting](#troubleshooting)

---

## Stripe Setup

### Step 1: Create Stripe Account

1. Go to [stripe.com](https://stripe.com)
2. Sign up for an account
3. Complete business verification (required for live mode)

### Step 2: Get API Keys

1. Navigate to [Dashboard → Developers → API keys](https://dashboard.stripe.com/apikeys)
2. You'll see two sets of keys:
   - **Test mode** (for development)
   - **Live mode** (for production)

**Copy these keys:**
- **Publishable key**: `pk_test_...` or `pk_live_...`
- **Secret key**: `sk_test_...` or `sk_live_...`

### Step 3: Install Stripe Gem

Add to your **host application's** `Gemfile`:

```ruby
# Gemfile
gem 'stripe', '~> 10.0'
```

Then run:
```bash
bundle install
```

### Step 4: Configure Environment Variables

Add to `.env` (recommended) or environment:

```bash
# For Development (Test Mode)
STRIPE_PUBLISHABLE_KEY=pk_test_51Hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_test_51Hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# For Production (Live Mode)
STRIPE_PUBLISHABLE_KEY=pk_live_51Hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_live_51Hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 5: Configure in Initializer (Optional)

Alternatively, configure in `config/initializers/scheduling.rb`:

```ruby
Scheduling.configure do |config|
  config.stripe_publishable_key = ENV['STRIPE_PUBLISHABLE_KEY']
  config.stripe_secret_key = ENV['STRIPE_SECRET_KEY']
end
```

### Step 6: Enable Payment Mode on Event Types

```ruby
event_type = Scheduling::EventType.find(1)

# For mandatory payment
event_type.update!(
  requires_payment: true,
  payment_required_to_book: true,
  price_cents: 15000,  # $150.00
  price_currency: 'USD'
)

# For optional payment
event_type.update!(
  requires_payment: true,
  payment_required_to_book: false,
  price_cents: 5000,  # $50.00
  price_currency: 'USD'
)
```

---

## Culqi Setup

### Step 1: Create Culqi Account

1. Go to [culqi.com](https://culqi.com)
2. Sign up for a Peruvian business account
3. Complete KYC verification

### Step 2: Get API Keys

1. Log into [Culqi Panel](https://integ-panel.culqi.com/)
2. Navigate to **Desarrollo → API Keys**
3. You'll see:
   - **Integración** (test mode)
   - **Producción** (live mode)

**Copy these keys:**
- **Public Key**: `pk_test_...` or `pk_live_...`
- **Secret Key**: `sk_test_...` or `sk_live_...`

### Step 3: Install Culqi Gem

Culqi doesn't have an official Ruby gem, so you'll use direct HTTP requests (already implemented in `CulqiPaymentService`).

No gem installation needed! The service uses `Net::HTTP` directly.

### Step 4: Configure Environment Variables

Add to `.env`:

```bash
# For Development (Integración)
CULQI_PUBLIC_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxxx
CULQI_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxxx

# For Production
CULQI_PUBLIC_KEY=pk_live_xxxxxxxxxxxxxxxxxxxxxxxx
CULQI_SECRET_KEY=sk_live_xxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 5: Configure in Initializer (Optional)

```ruby
Scheduling.configure do |config|
  config.culqi_public_key = ENV['CULQI_PUBLIC_KEY']
  config.culqi_secret_key = ENV['CULQI_SECRET_KEY']
end
```

### Step 6: Enable Payment Mode

```ruby
event_type = Scheduling::EventType.find(1)

event_type.update!(
  requires_payment: true,
  payment_required_to_book: true,
  price_cents: 15000,  # S/. 150.00
  price_currency: 'PEN'  # Peruvian Soles
)
```

### Step 7: Frontend Implementation

The Culqi payment integration is **fully implemented** with a Stimulus controller and automatic UI integration.

**How it works:**

1. **Automatic UI**: When `requires_payment: true` and `payment_required_to_book: true`, the booking form automatically shows a Culqi payment button instead of a regular submit button
2. **Culqi Checkout v4**: Uses the official Culqi.js v4 modal for secure payment collection
3. **3D Secure Support**: Automatically handles 3DS authentication when required by the bank
4. **Form Integration**: Payment token is collected and submitted with the booking form

**Files involved:**

- `app/javascript/controllers/scheduling/culqi_payment_controller.js` - Stimulus controller
- `app/views/scheduling/public_bookings/new.html.erb` - Includes Culqi.js and payment UI
- `app/services/scheduling/culqi_payment_service.rb` - Backend payment processing
- `config/initializers/culqi.rb` - API key configuration

**What the Stimulus controller does:**

```javascript
// Validates form
// Opens Culqi Checkout modal
// Receives payment token from Culqi
// Adds token to form as hidden field
// Submits form to create booking with payment
```

**User Flow (Mandatory Payment):**

1. User fills out booking form (name, email, phone, etc.)
2. User clicks **"Pagar Ahora S/. 150.00"** button
3. Culqi Checkout modal opens with card payment form
4. User enters card details (Culqi validates and tokenizes)
5. Token is returned to frontend
6. Form automatically submits with booking data + payment token
7. Backend creates booking and processes payment in one transaction
8. User redirected to confirmation page (or sees error message)

**Customization:**

The payment button and UI are automatically styled with Tailwind CSS and support all 4 locales (es, en, pt, fr).

**No additional setup required!** Just configure your Culqi API keys and the frontend works automatically.

---

## Configuration

### Full Initializer Example

```ruby
# config/initializers/scheduling.rb

Scheduling.configure do |config|
  # Payment gateway credentials
  config.stripe_publishable_key = ENV['STRIPE_PUBLISHABLE_KEY']
  config.stripe_secret_key = ENV['STRIPE_SECRET_KEY']
  config.culqi_public_key = ENV['CULQI_PUBLIC_KEY']
  config.culqi_secret_key = ENV['CULQI_SECRET_KEY']

  # Default currency
  config.default_currency = 'PEN'
  config.available_currencies = ['PEN', 'USD', 'EUR', 'GBP']

  # Payment providers (both enabled by default)
  config.payment_providers = [:stripe, :culqi]
end
```

### Event Type Payment Configuration

**Database Fields:**
```ruby
t.boolean :requires_payment, default: false
t.boolean :payment_required_to_book, default: true
t.integer :price_cents, default: 0
t.string :price_currency, default: 'PEN'
```

**Payment Modes:**

```ruby
# Mode 1: No Payment (Free)
event_type.update!(
  requires_payment: false
)

# Mode 2: Optional Payment
event_type.update!(
  requires_payment: true,
  payment_required_to_book: false,
  price_cents: 5000,
  price_currency: 'USD'
)

# Mode 3: Mandatory Payment
event_type.update!(
  requires_payment: true,
  payment_required_to_book: true,
  price_cents: 10000,
  price_currency: 'PEN'
)
```

---

## Payment Flows

### Flow 1: No Payment (Free)

```
Client Flow:
1. Select date/time
2. Enter details
3. Click "Confirm Booking"
4. ✅ Booking confirmed immediately

Database:
- booking.payment_status = 'not_required'
- No Payment record created
```

### Flow 2: Optional Payment

```
Client Flow:
1. Select date/time
2. Enter details
3. Click "Confirm Booking"
4. ✅ Booking confirmed
5. Confirmation page shows "Pay Now" button
6. Client can pay now OR pay later via email link

Database:
- booking.payment_status = 'pending'
- Payment record created when client clicks "Pay Now"
- After successful payment: booking.payment_status = 'paid'
```

### Flow 3: Mandatory Payment

```
Client Flow:
1. Select date/time
2. Enter details
3. Payment form appears (MUST complete)
4. Enter card details
5. Payment processed
6. ✅ Booking confirmed (only if payment succeeds)

Database:
- Booking NOT created until payment succeeds
- If payment fails: booking not saved, client returns to payment step
- After success: booking.payment_status = 'paid'
```

### Controller Flow

**In `PublicBookingsController#create`:**

```ruby
def create
  @booking = @event_type.bookings.build(booking_params)
  # ... set member, client, etc ...

  # Handle payment if required
  if @event_type.requires_payment && @event_type.payment_required_to_book
    payment_result = process_payment

    unless payment_result[:success]
      @booking.errors.add(:base, payment_result[:error])
      render :new and return
    end
  end

  if @booking.save
    redirect_to booking_confirmation_path(@booking.uid)
  else
    render :new
  end
end

private

def process_payment
  provider = params[:payment_provider] || "stripe"

  case provider
  when "stripe"
    StripePaymentService.new(@booking, params[:payment_method_id]).process
  when "culqi"
    CulqiPaymentService.new(@booking, params[:token_id]).process
  end
end
```

---

## Testing Payments

### Stripe Test Cards

Use these test cards in **test mode**:

| Card Number | Scenario | Result |
|-------------|----------|--------|
| `4242 4242 4242 4242` | Success | Payment succeeds |
| `4000 0000 0000 0002` | Declined | Card declined |
| `4000 0000 0000 9995` | Insufficient funds | Payment fails |
| `4000 0025 0000 3155` | 3D Secure required | Requires authentication |

**Use any future expiry date and any 3-digit CVC.**

[Full list of test cards](https://stripe.com/docs/testing#cards)

### Culqi Test Cards

In **integración mode**, use:

| Card Number | Scenario |
|-------------|----------|
| `4111 1111 1111 1111` | Success |
| `4000 0000 0000 0002` | Declined |

**CVC**: Any 3 digits
**Expiry**: Any future date

### Testing in Console

```ruby
# Create test booking
member = Scheduling::Member.first
event_type = member.event_types.create!(
  title: "Paid Consultation",
  duration_minutes: 30,
  requires_payment: true,
  payment_required_to_book: true,
  price_cents: 5000,  # $50 or S/. 50
  price_currency: 'USD'
)

client = member.organization.clients.create!(
  first_name: "Test",
  last_name: "Client",
  email: "test@example.com"
)

booking = event_type.bookings.create!(
  member: member,
  client: client,
  start_time: 1.day.from_now,
  timezone: 'America/Lima'
)

# Test Stripe payment
service = Scheduling::StripePaymentService.new(booking, 'pm_card_visa')
result = service.process
# => { success: true, payment: #<Payment...> }

# Check payment status
booking.reload.payment_status  # => "paid"
booking.payment  # => #<Payment ...>
```

---

## Refunds

### Automatic Refunds on Cancellation

When a booking with payment is cancelled:

```ruby
booking.cancel!(reason: "Client requested cancellation")
```

**What happens:**
1. Booking status → `cancelled`
2. `PaymentRefundJob` enqueued
3. Payment gateway API called for refund
4. Payment status → `refunded`
5. Booking payment_status → `refunded`

### Manual Refund

```ruby
payment = Scheduling::Payment.find(1)

# Via Stripe
Scheduling::StripePaymentService.refund(payment)

# Via Culqi
Scheduling::CulqiPaymentService.refund(payment)
```

### Refund Timelines

- **Stripe**: 5-10 business days to cardholder
- **Culqi**: 15-30 business days to cardholder

---

## Troubleshooting

### Common Issues

#### 1. "Stripe gem not available"

**Error**: `NotImplementedError: Stripe gem not available`

**Solution**: Add to your host app's Gemfile:
```ruby
gem 'stripe', '~> 10.0'
```
Then `bundle install`

#### 2. "No API key configured"

**Check:**
```ruby
# In Rails console
ENV['STRIPE_SECRET_KEY']  # Should return your key
Scheduling.configuration.stripe_secret_key  # Or this
```

**Solution**: Set environment variables or configure in initializer

#### 3. Payment Fails Silently

**Check logs:**
```bash
tail -f log/development.log | grep -i "payment\|stripe\|culqi"
```

**Common causes:**
- Invalid API key
- Test mode key used in production (or vice versa)
- Card declined
- Amount too low (minimum $0.50 USD for Stripe)

#### 4. Booking Created Without Payment

**Check:**
```ruby
event_type.requires_payment  # Should be true
event_type.payment_required_to_book  # Should be true for mandatory
```

**Issue**: If `payment_required_to_book` is false, payment is optional

#### 5. Refund Not Processing

**Check:**
```ruby
payment.external_transaction_id  # Should exist
payment.payment_provider  # Should be 'stripe' or 'culqi'
```

**Solution**: Refunds require the original transaction ID

---

## Security Best Practices

1. **Never commit API keys**: Use environment variables
2. **Use HTTPS in production**: Required by payment processors
3. **Validate on server**: Never trust client-side payment confirmation
4. **Log all transactions**: For auditing and dispute resolution
5. **Handle webhooks**: Implement Stripe/Culqi webhooks for payment confirmation (recommended)
6. **PCI Compliance**: Use Stripe Elements or Culqi.js (never store card details)

### Environment Variables Checklist

**Development (.env):**
```bash
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
CULQI_PUBLIC_KEY=pk_test_...
CULQI_SECRET_KEY=sk_test_...
```

**Production (ENV on server):**
```bash
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_SECRET_KEY=sk_live_...
CULQI_PUBLIC_KEY=pk_live_...
CULQI_SECRET_KEY=sk_live_...
```

**Important**: Add `.env` to `.gitignore`!

---

## Additional Resources

### Stripe
- [Stripe Documentation](https://stripe.com/docs)
- [Testing Guide](https://stripe.com/docs/testing)
- [Ruby Library](https://stripe.com/docs/api?lang=ruby)
- [Webhooks](https://stripe.com/docs/webhooks)

### Culqi
- [Culqi Documentation](https://docs.culqi.com/)
- [API Reference](https://apidocs.culqi.com/)
- [Integration Guide](https://docs.culqi.com/#integraci-n)

### MoneyRails
- [MoneyRails Gem](https://github.com/RubyMoney/money-rails)
- Used for currency handling in the engine

---

## Support

If you encounter issues:

1. Check the logs: `log/development.log`
2. Verify API keys are set correctly
3. Test with test mode cards first
4. Check payment service responses for error messages
5. Review Stripe/Culqi dashboard for transaction details

For bugs or feature requests, please open an issue on the project repository.
