defmodule Amortisen.Schedules.PriceTable do
  @moduledoc """
  Builds a schedule table using a Price amortization system.
  """

  alias Amortisen.Price.{Input, Calculator}
  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.{Table, Line}

  @default_zero Money.new(0)

  @doc """
  Build a complete schedule table using a `%PriceInput{}` and `%CreditPolicy{}`.

  The total of lines will be equal to payment term + 1, because the first line
  represent the period to customer start pay. So, the `outstanding_balance` value
  is the total which the customer will pay (with interest, taxes), and the others values
  are zero.

  The date of second line will be the shifted date based on the `payment_lack_limit`
  of a `%CreditPolicy{}`.

  ## Examples:

      iex> build_schedule_table(price_input, credit_policy)
      %Table{}

  """
  def build_schedule_table(%Input{} = price_input, %CreditPolicy{} = credit_policy) do
    calculated_values = Calculator.calculate_base_values(price_input, credit_policy)

    %Table{
      schedule_lines: build_schedule_lines(calculated_values, price_input),
      financial_transaction_taxes: calculated_values.funded_taxes_total_value
    }
  end

  defp build_schedule_lines(price_base_values, price_input) do
    [_head | amortization_table] = price_base_values.amortization_table

    [
      build_first_line(price_base_values)
      | build_schedule_line(price_base_values, amortization_table, 1, price_input)
    ]
  end

  defp build_first_line(price_base_values) do
    %Line{
      date: Timex.today(),
      interest: @default_zero,
      principal: @default_zero,
      life_insurance: @default_zero,
      realty_insurance: @default_zero,
      outstanding_balance: price_base_values.outstanding_balance
    }
  end

  defp build_schedule_line(_, [], _, _), do: []

  defp build_schedule_line(price_base_values, amortization_table, line_index, price_input) do
    installment_date =
      shift_schedule_line_date(
        line_index,
        Timex.today(),
        price_input.number_of_days_until_first_payment
      )

    [amortization_info_line | amortizations_tail] = amortization_table

    interest =
      Money.subtract(
        price_base_values.installment_amount,
        amortization_info_line.amortization
      )

    [
      %Line{
        date: installment_date,
        interest: interest,
        principal: amortization_info_line.amortization,
        life_insurance: @default_zero,
        realty_insurance: @default_zero,
        outstanding_balance: amortization_info_line.line_outstanding_balance
      }
    ] ++ build_schedule_line(price_base_values, amortizations_tail, line_index + 1, price_input)
  end

  defp shift_schedule_line_date(line_index, started_at, payment_lack_limit) do
    shifted_months = div(payment_lack_limit, 30) + (line_index - 1)
    Timex.shift(started_at, months: shifted_months)
  end
end
