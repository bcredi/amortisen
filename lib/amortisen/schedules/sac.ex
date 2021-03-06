defmodule Amortisen.Schedules.Sac do
  @moduledoc """
  Defines a `Sac` struct and a function to build a complete schedule table
  using a SAC amortization system.

  The `Sac` struct is defined to be used with `build_schedule_table/4` function.
  It represents the required params to calculate a complete schedule table.
  """

  @type t :: %__MODULE__{
          started_at: Date.t(),
          loan_amount: Money.t(),
          total_loan_amount: Money.t(),
          realty_value: Money.t(),
          payment_term: integer(),
          has_iof: boolean()
        }

  @enforce_keys [:loan_amount, :total_loan_amount, :payment_term, :realty_value, :started_at]
  defstruct [
    :loan_amount,
    :total_loan_amount,
    :payment_term,
    :realty_value,
    :started_at,
    has_iof: true
  ]

  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.{Line, Sac, Table}

  import Amortisen.FinancialTransactionTaxes
  import Amortisen.MonthlyExtraPayments

  @doc """
  Build a complete schedule table using a `%CreditPolicy{}`.

  The total of lines will be equal to payment term + 1, because the first line
  represent the period to customer start pay. So, the `outstanding_balance` value
  is the total which the customer will pay (with interest, taxes), and the others values
  are zero.

  The date of second line will be the shifted date based on the `payment_lack_limit`
  of a `%CreditPolicy{}`.

  ## Examples:

      iex> build_schedule_table(params, credit_policy)
      %Table{}

  """
  @spec build_schedule_table(Sac.t(), CreditPolicy.t(), float(), float()) :: Table.t()
  def build_schedule_table(
        %Sac{has_iof: true} = params,
        %CreditPolicy{} = credit_policy,
        life_insurance_fee,
        realty_insurance_fee
      ) do
    amortizations = Money.divide(params.total_loan_amount, params.payment_term)
    amortizations_iof = sum_amortizations_taxes(amortizations, credit_policy.payment_lack_limit)
    funded_iof = compute_funded_tax_amount(params.total_loan_amount, amortizations_iof)
    initial_outstanding_balance = Money.add(params.total_loan_amount, funded_iof)
    amortizations = Money.divide(initial_outstanding_balance, params.payment_term)

    %Table{
      schedule_lines: [
        first_schedule_line(initial_outstanding_balance)
        | build_schedule_lines(
            amortizations,
            credit_policy,
            initial_outstanding_balance,
            params,
            life_insurance_fee,
            realty_insurance_fee
          )
      ],
      financial_transaction_taxes: funded_iof
    }
  end

  def build_schedule_table(
        %Sac{has_iof: false} = params,
        %CreditPolicy{} = credit_policy,
        life_insurance_fee,
        realty_insurance_fee
      ) do
    amortizations = Money.divide(params.total_loan_amount, params.payment_term)

    %Table{
      schedule_lines: [
        first_schedule_line(params.total_loan_amount)
        | build_schedule_lines(
            amortizations,
            credit_policy,
            params.total_loan_amount,
            params,
            life_insurance_fee,
            realty_insurance_fee
          )
      ],
      financial_transaction_taxes: Money.new(0)
    }
  end

  defp build_schedule_lines(
         amortizations,
         credit_policy,
         initial_outstanding_balance,
         params,
         life_insurance_fee,
         realty_insurance_fee
       ) do
    amortizations
    |> Enum.with_index(1)
    |> Enum.map(fn {amortization, line_index} ->
      interest_rate =
        credit_policy.interest_rate
        |> Decimal.div(100)
        |> Decimal.to_float()

      previous_balance =
        compute_outstanding_balance(initial_outstanding_balance, amortization, line_index - 1)

      current_balance =
        compute_outstanding_balance(initial_outstanding_balance, amortization, line_index)

      %Line{
        date: shift_schedule_line_date(line_index, params, credit_policy),
        interest: Money.multiply(previous_balance, interest_rate),
        principal: amortization,
        life_insurance: life_insurance_amount(current_balance, life_insurance_fee),
        realty_insurance: realty_insurance_amount(params.realty_value, realty_insurance_fee),
        outstanding_balance: current_balance
      }
    end)
  end

  defp compute_outstanding_balance(initial_outstanding_balance, _amortization, line_index)
       when line_index <= 0 do
    initial_outstanding_balance
  end

  defp compute_outstanding_balance(initial_outstanding_balance, amortization, line_index) do
    Money.subtract(
      initial_outstanding_balance,
      Money.multiply(amortization, line_index)
    )
  end

  defp shift_schedule_line_date(line_index, %__MODULE__{} = params, credit_policy) do
    shifted_months = div(credit_policy.payment_lack_limit, 30) + line_index - 1
    Timex.shift(params.started_at, months: shifted_months)
  end

  defp first_schedule_line(initial_outstanding_balance) do
    %Line{
      date: Timex.today(),
      interest: Money.new(0),
      principal: Money.new(0),
      life_insurance: Money.new(0),
      realty_insurance: Money.new(0),
      outstanding_balance: initial_outstanding_balance
    }
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
