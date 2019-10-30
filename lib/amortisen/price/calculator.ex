defmodule Amortisen.Price.Calculator do
  @moduledoc """
  Reprensets the calculated base values for Price table.
  """

  alias Amortisen.Price.{Input}
  alias Amortisen.{CreditPolicy, FinancialTransactionTaxes}

  @days_in_financial_year 365

  def calculate_base_values(%Input{} = price_input, %CreditPolicy{} = credit_policy) do
    interest_rate = credit_policy.interest_rate |> Decimal.div(100) |> Decimal.to_float()

    # Valor inicial financiado
    initial_outstanding_balance = calculate_initial_outstanding_balance(price_input)

    # Valor financiado com juros
    outstanding_balance =
      calculate_outstanding_balance_with_interest(
        initial_outstanding_balance,
        price_input,
        interest_rate
      )

    # Taxa de juros por parcela
    installment_interest_rate = calculate_installment_interest_rate(price_input, interest_rate)

    # Valor da parcela
    installment_amount =
      calculate_installment_amount(
        initial_outstanding_balance,
        installment_interest_rate
      )

    # Amortizações
    amortization_table =
      calculate_amortizations(
        installment_amount,
        interest_rate,
        outstanding_balance
      )

    # IOF por parcela
    amortizations_with_iof_tax =
      add_iof_tax_to_amortization_table(amortization_table, price_input)

    # Total de IOF
    financed_iof_tax_amount =
      calculate_financed_iof_tax(amortizations_with_iof_tax, initial_outstanding_balance)

    %{
      interest_rate: interest_rate,
      initial_outstanding_balance: initial_outstanding_balance,
      outstanding_balance: outstanding_balance,
      installment_amount: installment_amount,
      installment_interest_rate: installment_interest_rate,
      funded_taxes_total_value: financed_iof_tax_amount,
      amortization_table: amortization_table
    }
  end

  def update_lines_values_with_iof(%Input{} = price_input, %{} = calculated_values) do
    %{
      initial_outstanding_balance: initial_outstanding_balance,
      amortization_table: amortization_table,
      interest_rate: interest_rate,
      installment_interest_rate: installment_interest_rate
    } = calculated_values

    # IOF por parcela
    amortizations_with_iof_tax =
      add_iof_tax_to_amortization_table(amortization_table, price_input)

    # Total de IOF
    financed_iof_tax_amount =
      calculate_financed_iof_tax(amortizations_with_iof_tax, initial_outstanding_balance)

    outstanding_balance_without_interest =
      Decimal.add(initial_outstanding_balance, financed_iof_tax_amount)

    # Saldo devedor final
    outstanding_balance_with_iof =
      calculate_outstanding_balance_with_interest(
        outstanding_balance_without_interest,
        price_input,
        interest_rate
      )

    # Valor da Parcela final
    installment_amount_with_iof =
      calculate_installment_amount(
        outstanding_balance_with_iof,
        installment_interest_rate
      )

    calculated_values
    |> Map.put(:outstanding_balance, outstanding_balance_with_iof)
    |> Map.put(:installment_amount, installment_amount_with_iof)
    |> Map.put(:amortization_table, amortizations_with_iof_tax)
    |> Map.put(:funded_taxes_total_value, financed_iof_tax_amount)
  end

  def calculate_initial_outstanding_balance(%Input{} = input) do
    user_requested_value = input.user_requested_value.amount |> Decimal.div(100)
    operation_cost_value = input.operation_cost_value.amount |> Decimal.div(100)

    Decimal.add(user_requested_value, operation_cost_value)
  end

  @doc """
  PtBR: (Valor inicial financiado * (( 1 + Taxa de Juros ) ^ ( Dias de carencia / 30 ))

  Returns `%Money{}`

  ## Example

      iex> Amortisen.Price.Calculator.calculate_outstanding_balance_with_interest(outstanding_balance, input, interest_rate)
      %Money{}

  """
  @spec calculate_outstanding_balance_with_interest(
          Decimal.t(),
          Amortisen.Price.Input.t(),
          number
        ) ::
          Decimal.t()
  def calculate_outstanding_balance_with_interest(
        outstanding_balance,
        %Input{} = input,
        interest_rate
      ) do
    base = 1 + interest_rate
    exponent = input.number_of_days_until_first_payment / 30
    factor = :math.pow(base, exponent)

    factor
    |> Decimal.from_float()
    |> Decimal.mult(outstanding_balance)
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
    dividend_base = 1 + interest_rate

    months_before_first_payment = input.number_of_days_until_first_payment / 30
    dividend_exponent = input.payment_term + months_before_first_payment

    dividend = :math.pow(dividend_base, dividend_exponent) * interest_rate

    divisor_base = 1 + interest_rate
    divisor_exponent = input.payment_term

    divisor = :math.pow(divisor_base, divisor_exponent) - 1

    dividend / divisor
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
    outstanding_balance
    |> Decimal.to_float()
    |> Kernel.*(installment_interest_rate)
    |> Decimal.from_float()
  end

  @doc """
  TODO
  """
  def calculate_amortizations(
        installment_amount,
        interest_rate,
        current_outstanding_balance
      ) do
    initial_line = %{
      line_index: 0,
      line_outstanding_balance: current_outstanding_balance,
      amortization: nil,
      interest: Decimal.from_float(0.00)
    }

    calculate_lines_amortization(initial_line, installment_amount, interest_rate)
  end

  @doc """
  TODO
  """
  def add_iof_tax_to_amortization_table(amortization_table, input) do
    # Ignore the head
    [head | amortization_lines] = amortization_table
    updated_head = Map.put(head, :iof, Decimal.from_float(0.00))

    updated_lines =
      amortization_lines
      |> Enum.map(&add_iof(&1, input.number_of_days_until_first_payment))

    [updated_head] ++ updated_lines
  end

  @doc """
  TODO
  """
  def calculate_financed_iof_tax(amortizatons_with_iof_tax, outstanding_balance) do
    iof_amount = calculated_iof_total_amount(amortizatons_with_iof_tax)

    dividend = Decimal.mult(outstanding_balance, iof_amount)
    divisor = Decimal.sub(outstanding_balance, iof_amount)

    Decimal.div(dividend, divisor)
  end

  defp calculated_iof_total_amount(amortizatons_with_iof_tax) do
    amortizatons_with_iof_tax
    |> Enum.reduce(Decimal.new(0_00), fn line, acc -> Decimal.add(acc, line.iof) end)
  end

  defp calculate_lines_amortization(
         %{line_outstanding_balance: %{sign: sign, coef: coef}} = previous_line,
         _,
         _
       )
       when sign < 0 or coef == 0 do
    [%{previous_line | line_outstanding_balance: Decimal.from_float(0.00)}]
  end

  defp calculate_lines_amortization(%{} = previous_line, installment_amount, interest_rate) do
    part_01 =
      previous_line.line_outstanding_balance
      |> Decimal.to_float()
      |> Kernel.*(interest_rate)
      |> Decimal.from_float()

    amortization = Decimal.sub(installment_amount, part_01)

    next_outstading_balance = Decimal.sub(previous_line.line_outstanding_balance, amortization)

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

    iof_money =
      line.amortization
      |> Decimal.to_float()
      |> Money.parse!()
      |> FinancialTransactionTaxes.amortization_tax_amount(accumulated_days)

    iof = Decimal.div(iof_money.amount, 100)
    Map.put(line, :iof, iof)
  end

  def calculate_accumulated_days_until_installment_payment(
        installment_number,
        number_of_days_until_first_payment
      ) do
    (installment_number - 1)
    |> accumulated_days()
    |> Kernel.+(number_of_days_until_first_payment)
    |> normalize_days()
  end

  defp accumulated_days(0), do: 0
  # PtBR: O maximo de dias considerados é 365 (ano financeiro)
  defp accumulated_days(i) when i * 30 > @days_in_financial_year, do: @days_in_financial_year
  defp accumulated_days(i), do: i * 30

  defp normalize_days(amount) when amount >= @days_in_financial_year, do: @days_in_financial_year
  defp normalize_days(amount), do: amount
end
