module Scheduling
  class PaymentRefundJob < ApplicationJob
    queue_as :default

    def perform(payment_id)
      payment = Scheduling::Payment.find(payment_id)

      # Process refund through payment gateway
      success = case payment.payment_provider
                when 'stripe'
                  StripePaymentService.refund(payment)
                when 'culqi'
                  CulqiPaymentService.refund(payment)
                else
                  # Manual refund - just mark as refunded
                  payment.update!(status: 'refunded')
                  true
                end

      if success
        payment.booking.update!(payment_status: 'refunded')
        Rails.logger.info("Payment refunded successfully for payment ##{payment_id}")
      else
        Rails.logger.error("Payment refund failed for payment ##{payment_id}")
        raise "Refund failed" # Will retry the job
      end
    rescue StandardError => e
      Rails.logger.error("Payment refund error for ##{payment_id}: #{e.message}")
      raise # Re-raise to retry the job
    end
  end
end
