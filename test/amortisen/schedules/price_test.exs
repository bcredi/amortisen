defmodule Amortisen.Schedules.PriceTest do
  use ExUnit.Case

  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.Price
  alias Amortisen.Schedules.Table

  @params %Price{
    realty_value: Money.new(30_000_000),
    loan_amount: Money.new(10_000_000),
    total_loan_amount: Money.new(10_545_000),
    payment_term: 120,
    started_at: Timex.today()
  }

  describe "#build_schedule_table/2" do
    test "returns a table struct" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 60,
        interest_rate: Decimal.from_float(1.09)
      }

      assert %Table{schedule_lines: lines, financial_transaction_taxes: iof} =
               Price.build_schedule_table(@params, credit_policy)

      assert is_list(lines)
      assert %Money{} = iof
    end
  end
end
