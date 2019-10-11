defmodule Amortisen.Price.CalculatorTest do
  use ExUnit.Case

  alias Amortisen.Price.{Calculator, Input}
  alias Amortisen.CreditPolicy

  @price_input %Input{
    number_of_days_until_first_payment: 90,
    user_requested_value: Money.new(100_000_00),
    operation_cost_value: Money.new(5_000_00),
    payment_term: 180
  }

  describe "#calculate_base_values/2" do
    test "returns the structure with correct values" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14)
      }

      expected_struct = %{
        outstanding_balance: Money.new(112_535_83),
        installment_amount: Money.new(1_474_57)
      }

      assert expected_struct == Calculator.calculate_base_values(@price_input, credit_policy)
    end
  end

  describe "#calculate_initial_outstanding_balance/1" do
    test "return the correct value" do
      assert Money.new(105_000_00) ==
               Calculator.calculate_initial_outstanding_balance(@price_input)
    end
  end

  describe "#calculate_outstanding_balance_with_interest/3" do
    test "with initial input returns the correct value" do
      outstanding_balance = Money.new(105_000_00)
      interest_rate = 0.0114

      assert Money.new(108_632_09) ==
               Calculator.calculate_outstanding_balance_with_interest(
                 outstanding_balance,
                 @price_input,
                 interest_rate
               )
    end

    test "with final input returns the correct value" do
      initial_outstanding_balance = Money.new(105_000_00)
      financed_iof_tax_amount = Money.new(3_773_13)
      outstanding_balance = Money.add(initial_outstanding_balance, financed_iof_tax_amount)
      interest_rate = 0.0114

      assert Money.new(112_535_74) ==
               Calculator.calculate_outstanding_balance_with_interest(
                 outstanding_balance,
                 @price_input,
                 interest_rate
               )
    end
  end

  describe "#calculate_installment_interest_rate/2" do
    test "returns the correct value" do
      interest_rate = 0.0114

      assert 0.0135564 ==
               Calculator.calculate_installment_interest_rate(@price_input, interest_rate)
    end
  end

  describe "#calculate_installment_amount/2" do
    test "returns the correct value" do
      outstanding_balance = Money.new(105_000_00)
      installment_interest_rate = 0.01356

      assert Money.new(1_423_80) ==
               Calculator.calculate_installment_amount(
                 outstanding_balance,
                 installment_interest_rate
               )
    end
  end

  describe "#calculate_amortizations/3" do
    test "returns a list of amortizations" do
      installment_amount = Money.new(1_423_42)
      interest_rate = 0.0114
      current_outstanding_balance = Money.new(108_632_09)

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
               amortization: nil
             } == first_line

      assert %{
               line_index: 180,
               line_outstanding_balance: Money.new(0),
               amortization: Money.new(1_407_39)
             } == last_line
    end
  end

  describe "#add_iof_tax_to_amortization_table/3" do
    test "returns a list of amortizations with IOF tax" do
      amortizations_table = [
        # HEAD
        %{},
        %{line_index: 1, amortization: Money.new(185_01)},
        %{line_index: 2, amortization: Money.new(187_12)},
        %{line_index: 3, amortization: Money.new(189_26)},
        %{line_index: 4, amortization: Money.new(191_41)}
      ]

      expected_iof_taxes = [Money.new(2_07), Money.new(2_55), Money.new(3_05), Money.new(3_55)]

      result_table =
        Calculator.add_iof_tax_to_amortization_table(amortizations_table, @price_input)

      calculated_iof_taxes = Enum.map(result_table, fn line -> line.iof end)

      calculated_iof_taxes
      |> Enum.with_index()
      |> Enum.each(fn {calculated_iof, index} ->
        assert(Money.equals?(calculated_iof, Enum.at(expected_iof_taxes, index)))
      end)
    end
  end

  describe "#calculate_financed_iof_tax/2" do
    test "returns the financed iof total value" do
      # Total: R$3.642,25
      amortizatons_with_iof_tax = [
        %{iof: Money.new(3_000_00)},
        %{iof: Money.new(600_00)},
        %{iof: Money.new(42_25)}
      ]

      initial_outstanding_balance = Money.new(105_000_00)

      assert Money.new(3_773_13) ==
               Calculator.calculate_financed_iof_tax(
                 amortizatons_with_iof_tax,
                 initial_outstanding_balance
               )
    end
  end
end
