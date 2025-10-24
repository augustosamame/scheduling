module Scheduling
  class CulqiPaymentService
    def initialize(booking, token_id)
      @booking = booking
      @token_id = token_id
      @event_type = booking.event_type
    end

    def process
      return { success: true } unless @event_type.requires_payment

      raise NotImplementedError, "Culqi gem not available. Install culqi-ruby gem." unless culqi_available?

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

      raise NotImplementedError, "Culqi gem not available. Install culqi-ruby gem." unless culqi_available?

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

    private

    def culqi_available?
      defined?(Culqi)
    end

    def self.culqi_available?
      defined?(Culqi)
    end
  end
end
