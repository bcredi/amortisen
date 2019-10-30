defmodule Amortisen.Schedules.PriceTableTest do
  use ExUnit.Case, async: true

  alias Amortisen.Price.Input
  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.PriceTable

  @zero_money Money.new(0)
  @numbers_of_days_until_first_payment 30

  @price_input %Input{
    number_of_days_until_first_payment: @numbers_of_days_until_first_payment,
    user_requested_value: Money.new(30_000_00),
    operation_cost_value: @zero_money,
    # 36 months
    payment_term: 36
  }

  @credit_policy %CreditPolicy{
    payment_lack_limit: @numbers_of_days_until_first_payment,
    interest_rate: Decimal.from_float(1.24),
    has_financed_iof: true
  }

  @credit_policy_without_iof %CreditPolicy{
    payment_lack_limit: @numbers_of_days_until_first_payment,
    interest_rate: Decimal.from_float(1.24),
    has_financed_iof: false
  }

  setup_all do
    {
      :ok,
      %{
        table_with_iof: PriceTable.build_schedule_table(@price_input, @credit_policy),
        table_without_iof:
          PriceTable.build_schedule_table(@price_input, @credit_policy_without_iof)
      }
    }
  end

  describe "#build_schedule_table/2" do
    test "the correct installment quantity given a credit policy that has financed iof",
         context do
      table_result = context.table_with_iof
      assert Enum.count(table_result.schedule_lines) == 37
    end

    test "the correct installment quantity given a credit policy that does not have financed iof",
         context do
      table_result = context.table_without_iof
      assert Enum.count(table_result.schedule_lines) == 37
    end

    test "the correct IOF amount given a credit policy that has financed iof", context do
      table_result = context.table_with_iof
      assert table_result.financial_transaction_taxes == Money.new(934_99)
    end

    test "the correct IOF amount given a credit policy that does not have financed iof",
         context do
      table_result = context.table_without_iof
      assert table_result.financial_transaction_taxes == Money.new(934_99)
    end

    test "the correct amortization total given a credit policy that has financed iof", context do
      principal_total_result =
        context.table_with_iof
        |> Map.get(:schedule_lines)
        |> Enum.reduce(Money.new(0_00), fn line, total ->
          line
          |> Map.get(:principal)
          |> Money.add(total)
        end)

      assert principal_total_result == Money.new(30_372_01)
    end

    test "the correct amortization total given a credit policy that does not have financed iof",
         context do
      principal_total_result =
        context.table_without_iof
        |> Map.get(:schedule_lines)
        |> Enum.reduce(Money.new(0_00), fn line, total ->
          line
          |> Map.get(:principal)
          |> Money.add(total)
        end)

      assert principal_total_result == Money.new(30_372_01)
    end

    test "the correct sum of the outstanding balances given a credit policy that has financed iof",
         context do
      outstanding_balance_sum_result =
        context.table_with_iof
        |> Map.get(:schedule_lines)
        |> Enum.reduce(Money.new(0_00), fn line, total ->
          line
          |> Map.get(:outstanding_balance)
          |> Money.add(total)
        end)

      assert outstanding_balance_sum_result == Money.new(603_089_46)
    end

    test "the correct interest total given a credit policy that has financed iof", context do
      interest_total_result =
        context.table_with_iof
        |> Map.get(:schedule_lines)
        |> Enum.reduce(Money.new(0_00), fn line, total ->
          line
          |> Map.get(:interest)
          |> Money.add(total)
        end)

      assert interest_total_result == Money.new(9_129_67)
    end
  end
end
