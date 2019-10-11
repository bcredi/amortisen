defmodule Amortisen.Price.Calculator do
  @moduledoc """
  Reprensets the calculated base values for Price table.
  """

  alias Amortisen.Price.{Input}
  alias Amortisen.{CreditPolicy, FinancialTransactionTaxes}

  @default_float_round 7
  @days_in_financial_year 365

  def calculate_base_values(%Input{} = price_input, %CreditPolicy{} = credit_policy) do
    interest_rate = credit_policy.interest_rate |> Decimal.div(100) |> Decimal.to_float()

    # Valor inicial financiado
    initial_outstanding_balance = calculate_initial_outstanding_balance(price_input)

    # Valor financiado com juros
    outstanding_balance_without_taxes =
      calculate_outstanding_balance_with_interest(
        initial_outstanding_balance,
        price_input,
        interest_rate
      )

    # Taxa de juros por parcela
    installment_interest_rate_without_taxes =
      calculate_installment_interest_rate(price_input, interest_rate)

    # Valor da parcela sem IOF
    installment_amount_without_taxes =
      calculate_installment_amount(
        initial_outstanding_balance,
        installment_interest_rate_without_taxes
      )

    # Amortizações
    amortization_table =
      calculate_amortizations(
        installment_amount_without_taxes,
        interest_rate,
        outstanding_balance_without_taxes
      )

    # IOF por parcela
    amortizatons_with_iof_tax = add_iof_tax_to_amortization_table(amortization_table, price_input)

    # Total de IOF
    financed_iof_tax_amount =
      calculate_financed_iof_tax(amortizatons_with_iof_tax, initial_outstanding_balance)

    outstanding_balance_without_interest =
      Money.add(initial_outstanding_balance, financed_iof_tax_amount)

    # Saldo devedor final
    outstanding_balance =
      calculate_outstanding_balance_with_interest(
        outstanding_balance_without_interest,
        price_input,
        interest_rate
      )

    # Valor da Parcela final
    installment_amount =
      calculate_installment_amount(
        outstanding_balance_without_interest,
        installment_interest_rate_without_taxes
      )

    %{
      outstanding_balance: outstanding_balance,
      installment_amount: installment_amount
    }
  end

  @doc """
    PtBR: Valor solicitado pelo cliente + Custo da operação
  """
  def calculate_initial_outstanding_balance(%Input{} = input) do
    Money.add(input.user_requested_value, input.operation_cost_value)
  end

  @doc """
  PtBR: (Valor inicial financiado * (( 1 + Taxa de Juros ) ^ ( Dias de carencia / 30 ))

  Returns `%Money{}`

  ## Example

      iex> Amortisen.Price.Calculator.calculate_outstanding_balance_with_interest(outstanding_balance, input, interest_rate)
      %Money{}

  """
  @spec calculate_outstanding_balance_with_interest(Money.t(), Amortisen.Price.Input.t(), number) ::
          Money.t()
  def calculate_outstanding_balance_with_interest(
        %Money{} = outstanding_balance,
        %Input{} = input,
        interest_rate
      ) do
    base = 1 + interest_rate
    exponent = input.number_of_days_until_first_payment / 30
    factor = :math.pow(base, exponent)

    Money.multiply(outstanding_balance, factor)
  end

  @doc """
    PtBr: ( ( (1 + Taxa de Juros) ^ (Prazo do contrato + dias de carencia) ) * Taxa de juros )
          --------------------------------------------------------------------------------------
                            ( ( (1 + Taxa de Juros) ^ (Prazo do contrato) ) - 1 )

  Returns `float`

  ## Example

      iex> Amortisen.Price.Calculator.calculate_outstanding_balance_with_interest(outstanding_balance, input, interest_rate)
      0.01356

  """
  @spec calculate_installment_interest_rate(Amortisen.Price.Input.t(), number) :: float
  def calculate_installment_interest_rate(%Input{} = input, interest_rate)
      when interest_rate > 0 do
    months_before_first_payment = input.number_of_days_until_first_payment / 30

    dividend_base = 1 + interest_rate
    dividend_exponent = input.payment_term + months_before_first_payment

    dividend = :math.pow(dividend_base, dividend_exponent) * interest_rate

    divisor_base = 1 + interest_rate
    divisor_exponent = input.payment_term

    divisor = :math.pow(divisor_base, divisor_exponent) - 1

    (dividend / divisor) |> Float.round(@default_float_round)
  end

  @doc """
  PtBr: ((Valor total financiado) * (Taxa de juros da parcela))

  Returns `%Money{}`

  ## Example

      iex> Amortisen.Price.Calculator.calculate_installment_amount(outstanding_balance, installment_interest_rate)
      %Money{}

  """
  @spec calculate_installment_amount(Money.t(), number) :: Money.t()
  def calculate_installment_amount(outstanding_balance, installment_interest_rate) do
    Money.multiply(outstanding_balance, installment_interest_rate)
  end

  @doc """
  TODO
  """
  def calculate_amortizations(
        %Money{} = installment_amount,
        interest_rate,
        %Money{} = current_outstanding_balance
      ) do
    initial_line = %{
      line_index: 0,
      line_outstanding_balance: current_outstanding_balance,
      amortization: nil
    }

    calculate_lines_amortization(initial_line, installment_amount, interest_rate)
  end

  @doc """
  TODO
  """
  def add_iof_tax_to_amortization_table(amortization_table, input) do
    # Ignore the head
    [_ | amortization_lines] = amortization_table

    amortization_lines
    |> Enum.map(&add_iof(&1, input.number_of_days_until_first_payment))
  end

  @doc """
  TODO
  """
  def calculate_financed_iof_tax(amortizatons_with_iof_tax, initial_outstanding_balance) do
    iof_amount =
      calculated_iof_total_amount(amortizatons_with_iof_tax)
      |> money_to_float()

    outstanding_balance = money_to_float(initial_outstanding_balance)

    dividend = outstanding_balance * iof_amount
    divisor = outstanding_balance - iof_amount

    (dividend / divisor) |> float_to_money()
  end

  defp calculated_iof_total_amount(amortizatons_with_iof_tax) do
    amortizatons_with_iof_tax
    |> Enum.reduce(Money.new(0_00), fn line, acc -> Money.add(acc, line.iof) end)
  end

  defp calculate_lines_amortization(
         %{line_outstanding_balance: %Money{amount: balance}} = previous_line,
         _,
         _
       )
       when balance <= 0 do
    [%{previous_line | line_outstanding_balance: Money.new(0)}]
  end

  defp calculate_lines_amortization(%{} = previous_line, installment_amount, interest_rate) do
    part_01 = Money.multiply(previous_line.line_outstanding_balance, interest_rate)
    amortization = Money.subtract(installment_amount, part_01)
    next_outstading_balance = Money.subtract(previous_line.line_outstanding_balance, amortization)

    next_line = %{
      line_index: previous_line.line_index + 1,
      line_outstanding_balance: next_outstading_balance,
      amortization: amortization
    }

    [previous_line | calculate_lines_amortization(next_line, installment_amount, interest_rate)]
  end

  defp add_iof(line, number_of_days_until_first_payment) do
    accumulated_days =
      calculate_accumulated_days_until_installment_payment(
        line.line_index,
        number_of_days_until_first_payment
      )

    iof = FinancialTransactionTaxes.amortization_tax_amount(line.amortization, accumulated_days)

    Map.put(line, :iof, iof)
  end

  defp calculate_accumulated_days_until_installment_payment(
         installment_number,
         number_of_days_until_first_payment
       ) do
    round(number_of_days_until_first_payment / 30)
    # Index 0 - Table header
    |> Kernel.+(installment_number - 1)
    |> accumulated_days
  end

  defp accumulated_days(0), do: 0
  # PtBR: O maximo de dias considerados é 365 (ano financeiro)
  defp accumulated_days(i) when i * 30 > @days_in_financial_year, do: @days_in_financial_year
  defp accumulated_days(i), do: i * 30

  defp money_to_float(%Money{} = money_value) do
    money_value.amount / 100
  end

  defp float_to_money(value) when is_number(value) do
    (value * 100) |> Kernel.trunc() |> Money.new()
  end
end
