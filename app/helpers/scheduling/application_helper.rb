module Scheduling
  module ApplicationHelper
    def format_price(price_cents, currency)
      return t('scheduling.event_types.free') if price_cents.nil? || price_cents <= 0

      # Convert cents to main currency unit
      amount = price_cents / 100.0

      # Use S/. symbol for PEN currency
      symbol = case currency.to_s.upcase
               when 'PEN' then 'S/.'
               when 'USD' then '$'
               when 'EUR' then '€'
               when 'GBP' then '£'
               else currency.to_s
               end

      # Format without decimals if whole number
      formatted_amount = amount % 1 == 0 ? amount.to_i : format('%.2f', amount)

      "#{symbol} #{formatted_amount}"
    end
  end
end
