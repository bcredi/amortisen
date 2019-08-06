defmodule Amortisen.Schedules.Price do
  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.Price
  alias Amortisen.Schedules.Table

  import Amortisen.FinancialTransactionTaxes

  @type t :: %__MODULE__{
          started_at: Date.t(),
          loan_amount: Money.t(),
          total_loan_amount: Money.t(),
          realty_value: Money.t(),
          payment_term: integer()
        }

  @enforce_keys [:loan_amount, :total_loan_amount, :payment_term, :realty_value, :started_at]
  defstruct [:loan_amount, :total_loan_amount, :payment_term, :realty_value, :started_at]

  def build_schedule_table(%Price{} = params, %CreditPolicy{} = credit_policy) do
    installment_interest = interest_for_installment(credit_policy, params)
    installment_amount = Money.multiply(params.total_loan_amount, installment_interest)

    outstanding_balance_interest = interest_for_outstanding_balance(credit_policy)

    outstanding_balance_amount =
      Money.multiply(params.total_loan_amount, outstanding_balance_interest)

    amortizations =
      amortizations(
        installment_amount,
        outstanding_balance_amount,
        credit_policy,
        params.payment_term
      )

    sum = sum_amortizations_taxes(amortizations, credit_policy.payment_lack_limit)

    IO.inspect(outstanding_balance_amount, label: :initial_outstanding_balance)
    IO.inspect(installment_amount, label: :installment)
    IO.inspect(List.last(amortizations), label: :first_amortization)
    IO.inspect(List.first(amortizations), label: :last_amortization)

    IO.inspect(Enum.reduce(amortizations, Money.new(0), fn a, acc -> Money.add(a, acc) end),
      label: :sum_amortization
    )

    IO.inspect(sum, label: :sum_taxes)

    %Table{
      schedule_lines: [],
      financial_transaction_taxes: Money.new(0)
    }
  end

  def amortizations(_installment_amount, _outstanding_balance_amount, _credit_policy, 0), do: []

  def amortizations(
        installment_amount,
        outstanding_balance_amount,
        %CreditPolicy{interest_rate: interest} = credit_policy,
        i
      ) do
    interest =
      interest
      |> Decimal.div(100)
      |> Decimal.to_float()

    interest_amount = Money.multiply(outstanding_balance_amount, interest)
    amortization = Money.subtract(installment_amount, interest_amount)

    amortizations(
      installment_amount,
      Money.subtract(outstanding_balance_amount, amortization),
      credit_policy,
      i - 1
    ) ++ [amortization]
  end

  @doc """
  Returns the interest for the outstanding balance.
  The formula is f(x) = i * (payment lack limit / 30).
  """
  def interest_for_outstanding_balance(%CreditPolicy{} = credit_policy) do
    credit_policy.interest_rate
    |> Decimal.div(100)
    |> Decimal.add(1)
    |> Decimal.to_float()
    |> :math.pow(credit_policy.payment_lack_limit / 30)
  end

  @doc """
  Returns the interest for the first installment.
  """
  def interest_for_installment(%CreditPolicy{} = credit_policy, %Price{
        payment_term: payment_term
      }) do
    payment_lack_limit = credit_policy.payment_lack_limit / 30

    interest_rate =
      credit_policy.interest_rate
      |> Decimal.div(100)
      |> Decimal.to_float()

    interest_rate * :math.pow(interest_rate + 1, payment_term + payment_lack_limit) /
      (:math.pow(interest_rate + 1, payment_term) - 1)
  end

  defp sum_amortizations_taxes(amortizations, payment_lack_limit) do
    amortizations
    |> Enum.with_index()
    |> Enum.map(fn {amortization, i} ->
      months = round(payment_lack_limit / 30)
      days = accumulated_days(i - 1 + months)
      amortization_tax_amount(amortization, days)
    end)
    |> Enum.reduce(Money.new(0), fn x, acc -> Money.add(x, acc) end)
  end

  @days_in_financial_year 365
  defp accumulated_days(0), do: 0
  defp accumulated_days(i) when i * 30 > @days_in_financial_year, do: @days_in_financial_year
  defp accumulated_days(i), do: i * 30
end
