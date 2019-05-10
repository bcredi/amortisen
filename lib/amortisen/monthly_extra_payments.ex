defmodule Amortisen.MonthlyExtraPayments do
  @moduledoc """
  Provide functions to calculate monthly extra payments,
  like insurances and administration fees.
  """

  @life_insurance_fee 0.048

  @doc """
  Returns the product of `outstanding_balance` by the insurance fee.

  ## Examples

      iex> life_insurance_amount(%Money{amount: 1_000_000})
      %Money{amount: 48_000}
  """
  @spec life_insurance_amount(Money.t()) :: Money.t()
  def life_insurance_amount(%Money{} = outstanding_balance) do
    Money.multiply(outstanding_balance, @life_insurance_fee / 100)
  end

  @realty_insurance_fee 0.025

  @doc """
  Returns the product of `realty_value` by the insurance fee.

  ## Examples

      iex> realty_insurance_amount(%Money{amount: 1_000_000})
      %Money{amount: 25_000}
  """
  @spec realty_insurance_amount(Money.t()) :: Money.t()
  def realty_insurance_amount(%Money{} = realty_value) do
    Money.multiply(realty_value, @realty_insurance_fee / 100)
  end

  @monthly_administration_fee 0.0

  @doc """
  Returns the sum of `outstanding_balance` with administration fees.

  ## Examples

      iex> monthly_administration_amount()
      %Money{amount: 1_000_000}
  """
  @spec monthly_administration_amount() :: Money.t()
  def monthly_administration_amount do
    Money.parse!(@monthly_administration_fee)
  end
end
