defmodule Amortisen.Schedules.PriceTest do
  use ExUnit.Case

  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.Price
  alias Amortisen.Schedules.Table

  @params %Price{
    realty_value: Money.new(15_000_000),
    loan_amount: Money.new(10_000_000),
    total_loan_amount: Money.new(10_500_000),
    payment_term: 120,
    started_at: Timex.today()
  }

  describe "#build_schedule_table/2" do
    test "returns a table struct" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      assert %Table{schedule_lines: lines, financial_transaction_taxes: iof} =
               Price.build_schedule_table(@params, credit_policy)

      assert is_list(lines)
      assert %Money{} = iof
    end
  end

  describe "#interest_for_first_installment/2" do
    test "returns a float" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14)
      }

      interest = Price.interest_for_first_installment(credit_policy, @params)
      assert is_float(interest)
      assert 0.015865271002266024 == interest
    end
  end

  describe "#interest_for_outstanding_balance/1" do
    test "returns a float" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 90,
        interest_rate: Decimal.from_float(1.14)
      }

      interest = Price.interest_for_outstanding_balance(credit_policy)
      assert is_float(interest)
      assert 1.4815439999999995 == interest
    end

    test "returns 1 when payment lack limit is zero" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 0,
        interest_rate: Decimal.from_float(1.14)
      }

      assert 1.0 == Price.interest_for_outstanding_balance(credit_policy)
    end

    test "returns the interest + 1 when payment lack limit is equal to 30" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }

      assert 1.14 == Price.interest_for_outstanding_balance(credit_policy)
    end

    test "returns lower interest then expected when payment lack limit is less than 30" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 0,
        interest_rate: Decimal.from_float(1.14)
      }

      assert 1.0 == Price.interest_for_outstanding_balance(credit_policy)

      assert 1.1350317835392 ==
               Price.interest_for_outstanding_balance(%{credit_policy | payment_lack_limit: 29})

      assert 1.091280933846754 ==
               Price.interest_for_outstanding_balance(%{credit_policy | payment_lack_limit: 20})
    end
  end

  describe "#amortization_amount/3" do
    test "returns the product of installment - (interest * balance)" do
      credit_policy = %CreditPolicy{
        payment_lack_limit: 30,
        interest_rate: Decimal.from_float(1.14)
      }
    end
  end
end
