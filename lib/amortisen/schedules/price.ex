defmodule Amortisen.Schedules.Pricex do
  @moduledoc """
  Defines a `Price` struct and a function to build a complete schedule table
  using a Price amortization system.

  The `Price` struct is defined to be used with `build_schedule_table/4` function.
  It represents the required params to calculate a complete schedule table.
  """

  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.Line
  alias Amortisen.Schedules.Pricex, as: Price
  alias Amortisen.Schedules.Table

  import Amortisen.FinancialTransactionTaxes
  import Amortisen.MonthlyExtraPayments

  @type t :: %__MODULE__{
          started_at: Date.t(),
          loan_amount: Money.t(),
          total_loan_amount: Money.t(),
          realty_value: Money.t(),
          payment_term: integer()
        }

  @enforce_keys [:loan_amount, :total_loan_amount, :payment_term, :realty_value, :started_at]
  defstruct [:loan_amount, :total_loan_amount, :payment_term, :realty_value, :started_at]

  def build_schedule_table(
        %Price{} = params,
        %CreditPolicy{} = credit_policy,
        life_insurance_fee,
        realty_insurance_fee
      ) do
    installment_interest = interest_for_installment(credit_policy, params)
    installment_amount = Money.multiply(params.total_loan_amount, installment_interest)
    outstanding_balance_interest = interest_for_outstanding_balance(credit_policy)

    outstanding_balance_amount =
      Money.multiply(params.total_loan_amount, outstanding_balance_interest)

    amortizations =
      build_amortization_list(
        installment_amount,
        outstanding_balance_amount,
        credit_policy,
        params.payment_term
      )

    sum = sum_amortizations_taxes(amortizations, credit_policy.payment_lack_limit)
    funded_taxes = compute_funded_tax_amount(params.total_loan_amount, sum)

    outstanding_balance_amount =
      Money.multiply(
        Money.add(params.total_loan_amount, funded_taxes),
        outstanding_balance_interest
      )

    installment_amount = Money.multiply(outstanding_balance_amount, installment_interest)

    %Table{
      schedule_lines:
        build_schedule_lines(
          params,
          credit_policy,
          installment_amount,
          life_insurance_fee,
          realty_insurance_fee
        ),
      financial_transaction_taxes: funded_taxes
    }
  end

  defp build_schedule_lines(
         %Price{payment_term: 1},
         _credit_policy,
         _installment_amount,
         _life_insurance_fee,
         _realty_insurance_fee
       ) do
    [
      %Line{
        date: Date.utc_today(),
        principal: Money.new(0),
        outstanding_balance: Money.new(0),
        interest: Money.new(0),
        life_insurance: Money.new(0),
        realty_insurance: Money.new(0)
      }
    ]
  end

  defp build_schedule_lines(
         params,
         credit_policy,
         installment_amount,
         life_insurance_fee,
         realty_insurance_fee
       ) do
    interest = credit_policy.interest_rate |> Decimal.div(100) |> Decimal.to_float()
    interest_amount = Money.multiply(params.total_loan_amount, interest)
    amortization = Money.subtract(installment_amount, interest_amount)
    outstanding_balance = Money.subtract(params.total_loan_amount, amortization)

    params = %{
      params
      | total_loan_amount: outstanding_balance,
        payment_term: params.payment_term - 1
    }

    [
      %Line{
        date: Date.utc_today(),
        principal: amortization,
        outstanding_balance: outstanding_balance,
        interest: interest_amount,
        life_insurance: life_insurance_amount(outstanding_balance, life_insurance_fee),
        realty_insurance: realty_insurance_amount(params.realty_value, realty_insurance_fee)
      }
    ] ++
      build_schedule_lines(
        params,
        credit_policy,
        installment_amount,
        life_insurance_fee,
        realty_insurance_fee
      )
  end

  defp build_amortization_list(_, _, _, 0) do
    []
  end

  defp build_amortization_list(
         installment_amount,
         outstanding_balance_amount,
         %CreditPolicy{interest_rate: interest} = credit_policy,
         i
       ) do
    interest = interest |> Decimal.div(100) |> Decimal.to_float()
    interest_amount = Money.multiply(outstanding_balance_amount, interest)
    amortization = Money.subtract(installment_amount, interest_amount)

    build_amortization_list(
      installment_amount,
      Money.subtract(outstanding_balance_amount, amortization),
      credit_policy,
      i - 1
    ) ++ [amortization]
  end

  def amortization_amount(installment_amount, outstanding_balance_amount, %CreditPolicy{
        interest_rate: interest
      }) do
    interest =
      interest
      |> Decimal.div(100)
      |> Decimal.to_float()

    interest_amount = Money.multiply(outstanding_balance_amount, interest)
    Money.subtract(installment_amount, interest_amount)
  end

  def outstanding_balance_amount(%Price{total_loan_amount: total_loan_amount}, interest) do
    Money.multiply(total_loan_amount, interest)
  end

  defp interest_for_outstanding_balance(%CreditPolicy{} = credit_policy) do
    credit_policy.interest_rate
    |> Decimal.div(100)
    |> Decimal.add(1)
    |> Decimal.to_float()
    |> :math.pow(credit_policy.payment_lack_limit / 30)
  end

  defp interest_for_installment(%CreditPolicy{} = credit_policy, %Price{
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
