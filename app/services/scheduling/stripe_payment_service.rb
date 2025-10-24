module Scheduling
  class StripePaymentService
    def initialize(booking, payment_method_id)
      @booking = booking
      @payment_method_id = payment_method_id
      @event_type = booking.event_type
    end

    def process
      return { success: true } unless @event_type.requires_payment

      raise NotImplementedError, "Stripe gem not available. Add 'stripe' to your Gemfile." unless stripe_available?

      begin
        # Create payment intent
        intent = Stripe::PaymentIntent.create(
          amount: @event_type.price_cents,
          currency: @event_type.price_currency.downcase,
          payment_method: @payment_method_id,
          confirm: true,
          description: "Booking: #{@event_type.title} with #{@booking.member.full_name}",
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

      raise NotImplementedError, "Stripe gem not available. Add 'stripe' to your Gemfile." unless stripe_available?

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

    private

    def stripe_available?
      defined?(Stripe)
    end

    def self.stripe_available?
      defined?(Stripe)
    end
  end
end
