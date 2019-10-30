defmodule Amortisen.Price.CalculatorTest do
  use ExUnit.Case, async: true

  alias Amortisen.Price.{Calculator, Input}
  alias Amortisen.CreditPolicy

  @zero_money Decimal.from_float(0.00)

  @price_input %Input{
    number_of_days_until_first_payment: 90,
    user_requested_value: Money.new(100_000_00),
    operation_cost_value: Money.new(5_000_00),
    payment_term: 180
  }

  @round_places 10

  describe "#calculate_base_values/2" do
    test "returns the correct values given a credit policy which finance iof" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14),
        has_financed_iof: true
      }

      result = Calculator.calculate_base_values(@price_input, credit_policy)
      outstanding_balance_result = Decimal.round(result.outstanding_balance, @round_places)
      installment_amount_result = Decimal.round(result.installment_amount, @round_places)

      assert Decimal.equal?(outstanding_balance_result, Decimal.from_float(108_632.0929621200))
      assert Decimal.equal?(installment_amount_result, Decimal.from_float(1_423.4186624740))
    end

    test "returns the correct values given a credit policy which doesn't finance iof" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14),
        has_financed_iof: false
      }

      result = Calculator.calculate_base_values(@price_input, credit_policy)
      outstanding_balance_result = Decimal.round(result.outstanding_balance, @round_places)
      installment_amount_result = Decimal.round(result.installment_amount, @round_places)

      assert Decimal.equal?(outstanding_balance_result, Decimal.from_float(108_632.0929621200))
      assert Decimal.equal?(installment_amount_result, Decimal.from_float(1423.4186624740))
    end
  end

  describe "#calculate_initial_outstanding_balance/1" do
    test "return the correct value" do
      expected_result = Decimal.from_float(105_000.00)
      result = Calculator.calculate_initial_outstanding_balance(@price_input)

      assert Decimal.equal?(expected_result, result)
    end
  end

  describe "#calculate_outstanding_balance_with_interest/3" do
    test "with initial input returns the correct value" do
      outstanding_balance = Decimal.from_float(105_000.00)
      interest_rate = 0.0114

      result =
        Calculator.calculate_outstanding_balance_with_interest(
          outstanding_balance,
          @price_input,
          interest_rate
        )
        |> Decimal.round(@round_places)

      assert Decimal.equal?(result, Decimal.from_float(108_632.0929621200))
    end

    test "with final input returns the correct value" do
      initial_outstanding_balance = Decimal.from_float(105_000.00)
      financed_iof_tax_amount = Decimal.from_float(3_773.13)
      outstanding_balance = Decimal.add(initial_outstanding_balance, financed_iof_tax_amount)
      interest_rate = 0.0114

      result =
        Calculator.calculate_outstanding_balance_with_interest(
          outstanding_balance,
          @price_input,
          interest_rate
        )
        |> Decimal.round(@round_places)

      assert Decimal.equal?(result, Decimal.from_float(112_535.7406661025))
    end
  end

  describe "#calculate_installment_interest_rate/2" do
    test "returns the correct value" do
      interest_rate = 0.0114

      assert 0.013556368214038427 ==
               Calculator.calculate_installment_interest_rate(@price_input, interest_rate)
    end
  end

  describe "#calculate_installment_amount/2" do
    test "returns the correct value" do
      outstanding_balance = Decimal.from_float(105_000.00)
      installment_interest_rate = 0.01356

      assert Decimal.from_float(1_423.80) ==
               Calculator.calculate_installment_amount(
                 outstanding_balance,
                 installment_interest_rate
               )
    end
  end

  describe "#calculate_amortizations/3" do
    test "returns a list of amortizations" do
      installment_amount = Decimal.from_float(1_423.42)
      interest_rate = 0.0114
      current_outstanding_balance = Decimal.from_float(108_632.09)

      lines_result =
        Calculator.calculate_amortizations(
          installment_amount,
          interest_rate,
          current_outstanding_balance
        )

      assert is_list(lines_result)

      [first_line | _] = lines_result
      last_line = List.last(lines_result)

      assert %{
               line_index: 0,
               line_outstanding_balance: current_outstanding_balance,
               amortization: nil,
               interest: @zero_money
             } == first_line

      assert 180 == last_line.line_index
      assert Decimal.equal?(Decimal.from_float(0.00), last_line.line_outstanding_balance)

      expected_amortization = Decimal.from_float(1407.385023426360)
      last_line_amortization = last_line.amortization |> Decimal.round(12)

      assert Decimal.equal?(expected_amortization, last_line_amortization)
    end
  end

  describe "#add_iof_tax_to_amortization_table/3" do
    test "returns a list of amortizations with IOF tax" do
      amortizations_table = [
        # HEAD
        %{},
        %{line_index: 1, amortization: Decimal.from_float(185.01)},
        %{line_index: 2, amortization: Decimal.from_float(187.12)},
        %{line_index: 3, amortization: Decimal.from_float(189.26)},
        %{line_index: 4, amortization: Decimal.from_float(191.41)}
      ]

      expected_iof_taxes = [
        Decimal.from_float(0.00),
        Decimal.from_float(2.07),
        Decimal.from_float(2.55),
        Decimal.from_float(3.05),
        Decimal.from_float(3.55)
      ]

      result_table =
        Calculator.add_iof_tax_to_amortization_table(amortizations_table, @price_input)

      Enum.map(result_table, fn line -> line.iof end)
      |> Enum.with_index()
      |> Enum.each(fn {calculated_iof, index} ->
        assert(Decimal.equal?(calculated_iof, Enum.at(expected_iof_taxes, index)))
      end)
    end
  end

  describe "#calculate_financed_iof_tax/2" do
    test "returns the financed iof total value" do
      # Total: R$3.642,25
      amortizatons_with_iof_tax = [
        %{iof: Decimal.from_float(3_000.00)},
        %{iof: Decimal.from_float(600.00)},
        %{iof: Decimal.from_float(42.25)}
      ]

      initial_outstanding_balance = Decimal.from_float(105_000.00)
      expected_result = Decimal.from_float(3_773.13278955)

      result =
        Calculator.calculate_financed_iof_tax(
          amortizatons_with_iof_tax,
          initial_outstanding_balance
        )
        |> Decimal.round(8)

      assert Decimal.equal?(expected_result, result)
    end
  end
end
