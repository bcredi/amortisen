defmodule Amortisen.Schedules.SacTest do
  use ExUnit.Case

  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.{Sac, Table}

  @params %Sac{
    realty_value: Money.new(15_000_000),
    loan_amount: Money.new(10_000_000),
    total_loan_amount: Money.new(10_500_000),
    payment_term: 120,
    started_at: Timex.today()
  }

  describe "#build_schedule_table/2" do
    test "return a table struct with schedule lines and financial transaction taxes" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      assert %Table{} = Sac.build_schedule_table(@params, credit_policy)
    end

    test "return a table struct with total lines equal to payment term + 1" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: lines} = Sac.build_schedule_table(@params, credit_policy)
      assert length(lines) == 121
    end

    test "returns the first schedule line date equal to started_at param" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: [first_line | _lines]} =
        Sac.build_schedule_table(@params, credit_policy)

      assert first_line.date == @params.started_at
    end

    test "returns the first schedule line values equal to zero" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: [first_line | _lines]} =
        Sac.build_schedule_table(@params, credit_policy)

      assert %Money{amount: 0} = first_line.interest
      assert %Money{amount: 0} = first_line.principal
      assert %Money{amount: 0} = first_line.monthly_extra_payment
      assert %Money{amount: 10_848_615} = first_line.outstanding_balance
    end

    test "returns the schedule lines date shifted by payment lack limit" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: [_first_line | lines]} =
        Sac.build_schedule_table(@params, credit_policy)

      lines
      |> Enum.with_index(1)
      |> Enum.each(fn {line, i} ->
        assert line.date == shift_schedule_line_date(@params.started_at, 90, i)
      end)
    end
  end

  def shift_schedule_line_date(started_at, payment_lack_limit, line_index) do
    shifted_months = div(payment_lack_limit, 30) + line_index - 1
    Timex.shift(started_at, months: shifted_months)
  end
end
