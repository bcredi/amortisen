defmodule Amortisen.MonthlyExtraPaymentsTest do
  use ExUnit.Case

  alias Amortisen.MonthlyExtraPayments

  @life_insurance_fee 0.027

  @realty_insurance_fee 0.016

  describe "#life_insurance_amount/1" do
    test "returns the product of outstanding balance by the insurance fee" do
      outstanding_balance = Money.parse!(100_000.0)

      assert %Money{amount: 2700} =
               MonthlyExtraPayments.life_insurance_amount(
                 outstanding_balance,
                 @life_insurance_fee
               )

      assert %Money{amount: 0} =
               MonthlyExtraPayments.life_insurance_amount(Money.new(0), @life_insurance_fee)
    end
  end

  describe "#realty_insurance_amount/1" do
    test "returns the product of realty value by the insurance fee" do
      realty_value = Money.parse!(300_000.0)

      assert %Money{amount: 4800} =
               MonthlyExtraPayments.realty_insurance_amount(realty_value, @realty_insurance_fee)

      assert %Money{amount: 0} =
               MonthlyExtraPayments.realty_insurance_amount(Money.new(0), @realty_insurance_fee)
    end
  end
end
