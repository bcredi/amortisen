defmodule Amortisen.MonthlyExtraPayments do
  @moduledoc """
  Provide functions to calculate monthly extra payments,
  like insurances and administration fees.
  """

  @doc """
  Returns the product of `outstanding_balance` by the insurance fee.

  ## Examples

      iex> life_insurance_amount(%Money{amount: 1_000_000}, 0.027)
      %Money{amount: 48_000}
  """
  @spec life_insurance_amount(Money.t(), float()) :: Money.t()
  def life_insurance_amount(%Money{} = outstanding_balance, life_insurance_fee) do
    Money.multiply(outstanding_balance, life_insurance_fee / 100)
  end

  @doc """
  Returns the product of `realty_value` by the insurance fee.

  ## Examples

      iex> realty_insurance_amount(%Money{amount: 1_000_000}, 0.016)
      %Money{amount: 25_000}
  """
  @spec realty_insurance_amount(Money.t(), float()) :: Money.t()
  def realty_insurance_amount(%Money{} = realty_value, realty_insurance_fee) do
    Money.multiply(realty_value, realty_insurance_fee / 100)
  end
end
