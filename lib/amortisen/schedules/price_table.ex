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
    calculated_data =
      Calculator.calculate_base_values(price_input, credit_policy)
      |> update_with_iof_policy(price_input, credit_policy)

    %Table{
      schedule_lines: build_schedule_lines(calculated_data, price_input),
      financial_transaction_taxes: decimal_to_money(calculated_data.funded_taxes_total_value)
    }
  end

  defp update_with_iof_policy(
         lines,
         %Input{} = input,
         %CreditPolicy{has_financed_iof: true}
       ) do
    Calculator.update_lines_values_with_iof(input, lines)
  end

  defp update_with_iof_policy(lines, %Input{}, %CreditPolicy{has_financed_iof: false}), do: lines

  defp build_schedule_lines(price_base_values, price_input) do
    [_head | amortization_table] = price_base_values.amortization_table

    build_schedule_line(price_base_values, amortization_table, 0, price_input)
  end

  defp build_schedule_line(price_base_values, amortization_table, 0, price_input) do
    [
      %Line{
        date: Timex.today(),
        interest: @default_zero,
        principal: @default_zero,
        life_insurance: @default_zero,
        realty_insurance: @default_zero,
        outstanding_balance: decimal_to_money(price_base_values.outstanding_balance),
        iof: @default_zero
      }
    ] ++ build_schedule_line(price_base_values, amortization_table, 1, price_input)
  end

  defp build_schedule_line(
         price_base_values,
         [amortization_line_info | other_lines],
         line_index,
         price_input
       )
       when length(other_lines) <= 0 do
    [build_line(price_base_values, amortization_line_info, line_index, price_input)]
  end

  defp build_schedule_line(price_base_values, amortization_table, line_index, price_input) do
    [amortization_line_info | amortizations_tail] = amortization_table

    [
      build_line(price_base_values, amortization_line_info, line_index, price_input)
    ] ++ build_schedule_line(price_base_values, amortizations_tail, line_index + 1, price_input)
  end

  defp build_line(price_base_values, amortization_line_info, line_index, price_input) do
    installment_date =
      shift_schedule_line_date(
        line_index,
        Timex.today(),
        price_input.number_of_days_until_first_payment
      )

    interest =
      Decimal.sub(price_base_values.installment_amount, amortization_line_info.amortization)

    %Line{
      date: installment_date,
      interest: decimal_to_money(interest),
      principal: decimal_to_money(amortization_line_info.amortization),
      life_insurance: @default_zero,
      realty_insurance: @default_zero,
      outstanding_balance: decimal_to_money(amortization_line_info.line_outstanding_balance),
      iof: decimal_to_money(Map.get(amortization_line_info, :iof, Decimal.from_float(0.00)))
    }
  end

  defp shift_schedule_line_date(line_index, started_at, payment_lack_limit) do
    shifted_months = div(payment_lack_limit, 30) + (line_index - 1)
    Timex.shift(started_at, months: shifted_months)
  end

  defp decimal_to_money(decimal_value) do
    decimal_value
    |> Decimal.round(2)
    |> Decimal.to_float()
    |> Money.parse!()
  end
end
