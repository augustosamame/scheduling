module Scheduling
  class Payment < ApplicationRecord
    belongs_to :booking

    monetize :amount_cents, with_currency: :amount_currency if defined?(MoneyRails)

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
        # Call payment processor's refund API
        success = case payment_provider
        when 'stripe'
          StripePaymentService.refund(self)
        when 'culqi'
          CulqiPaymentService.refund(self)
        else
          # Manual refund - just mark as refunded
          update!(status: 'refunded')
          true
        end

        if success
          booking.update!(payment_status: 'refunded')
        else
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
