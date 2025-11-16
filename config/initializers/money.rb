if defined?(MoneyRails)
  # Register custom PEN currency with S/. symbol
  Money::Currency.register(
    {
      priority: 1,
      iso_code: "PEN",
      name: "Peruvian Sol",
      symbol: "S/.",
      subunit: "Céntimo",
      subunit_to_unit: 100,
      decimal_mark: ".",
      thousands_separator: ","
    }
  )

  MoneyRails.configure do |config|
    config.default_currency = :pen
    config.locale_backend = :i18n
    config.rounding_mode = BigDecimal::ROUND_HALF_UP
    config.default_bank = Money::Bank::VariableExchange.new(Money::RatesStore::Memory.new)

    # Format without cents if amount is whole number
    config.no_cents_if_whole = true

    # Set exchange rates (update periodically via API in production)
    config.default_bank.add_rate('USD', 'PEN', 3.75)
    config.default_bank.add_rate('EUR', 'PEN', 4.10)
    config.default_bank.add_rate('GBP', 'PEN', 4.80)
  end
end
