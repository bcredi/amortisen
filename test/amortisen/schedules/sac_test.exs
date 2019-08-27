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

  @life_insurance_fee 0.027

  @realty_insurance_fee 0.016

  describe "#build_schedule_table/2" do
    test "return a table struct with schedule lines and financial transaction taxes" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      assert %Table{} =
               Sac.build_schedule_table(
                 @params,
                 credit_policy,
                 @life_insurance_fee,
                 @realty_insurance_fee
               )
    end

    test "return a table struct with schedule lines and financial equals zero" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      table =
        Sac.build_schedule_table(
          Map.put(@params, :has_iof, false),
          credit_policy,
          @life_insurance_fee,
          @realty_insurance_fee
        )

      assert %Table{} = table
      assert Money.to_string(table.financial_transaction_taxes) == "0.00"
    end

    test "return a table struct with total lines equal to payment term + 1" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: lines} =
        Sac.build_schedule_table(
          @params,
          credit_policy,
          @life_insurance_fee,
          @realty_insurance_fee
        )

      assert length(lines) == 121
    end

    test "returns the first schedule line date equal to started_at param" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: [first_line | _lines]} =
        Sac.build_schedule_table(
          @params,
          credit_policy,
          @life_insurance_fee,
          @realty_insurance_fee
        )

      assert first_line.date == @params.started_at
    end

    test "returns the first schedule line values equal to zero" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: [first_line | _lines]} =
        Sac.build_schedule_table(
          @params,
          credit_policy,
          @life_insurance_fee,
          @realty_insurance_fee
        )

      assert %Money{amount: 0} = first_line.interest
      assert %Money{amount: 0} = first_line.principal
      assert %Money{amount: 0} = first_line.life_insurance
      assert %Money{amount: 0} = first_line.realty_insurance
      assert %Money{amount: 10_848_037} = first_line.outstanding_balance
    end

    test "returns the schedule lines date shifted by payment lack limit" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14)
      }

      %Table{schedule_lines: [_first_line | lines]} =
        Sac.build_schedule_table(
          @params,
          credit_policy,
          @life_insurance_fee,
          @realty_insurance_fee
        )

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
