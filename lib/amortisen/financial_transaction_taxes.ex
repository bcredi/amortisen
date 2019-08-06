defmodule Amortisen.FinancialTransactionTaxes do
  @moduledoc """
  Provide functions to compute Brazil financial transaction taxes (IOF).
  """

  @fixed_rate 0.38
  @daily_rate 0.0082

  @doc """
  Used to compute the taxes (IOF) for each amortization amount of a schedule table.
  (amortization * (fixed_rate + daily_rate * accumulated_days) / 100)

  ## Examples:

      iex> amortization_tax_amount(Money.new(892_59), 30)
      %Money{currency: :BRL, amount: 559}

      iex> amortization_tax_amount(Money.new(0), 30)
      %Money{currency: :BRL, amount: 0}

  """
  @spec amortization_tax_amount(Money.t(), integer()) :: Money.t()
  def amortization_tax_amount(%Money{} = amortization, accumulated_days)
      when is_integer(accumulated_days) do
    fixed_rate = Decimal.from_float(@fixed_rate)
    daily_rate = Decimal.from_float(@daily_rate)

    x = Decimal.mult(daily_rate, accumulated_days)
    x = Decimal.add(x, fixed_rate)
    x = Decimal.div(x, 100)

    Money.multiply(amortization, Decimal.to_float(x))
  end

  @doc """
  At Barigui, the financial transaction taxes are funded.
  So this function allow us to recalculate the final financial transaction tax amount
  based on a sum of taxes of each amortization amount.

  ## Examples:

      iex> compute_funded_tax_amount(Money.new(105_00000), Money.new(349_837))
      %Money{currency: :BRL, amount: 361_895}

      iex> compute_funded_tax_amount(Money.new(0), Money.new(349_837))
      %Money{currency: :BRL, amount: 0}

      iex> compute_funded_tax_amount(Money.new(105_00000), Money.new(0))
      %Money{currency: :BRL, amount: 0}

  """
  @spec amortization_tax_amount(Money.t(), Money.t()) :: Money.t()
  def compute_funded_tax_amount(%Money{} = loan_amount, %Money{} = amortizatios_taxes_amount) do
    y = Money.subtract(loan_amount, amortizatios_taxes_amount)
    x = Money.multiply(loan_amount, amortizatios_taxes_amount.amount / 100)
    z = round(x.amount / y.amount * 100)
    Money.new(z)
  end
end
