defmodule Amortisen.MonthlyExtraPaymentsTest do
  use ExUnit.Case

  alias Amortisen.MonthlyExtraPayments

  describe "#life_insurance_amount/1" do
    test "returns the product of outstanding balance by the insurance fee" do
      outstanding_balance = Money.parse!(100_000.0)

      assert %Money{amount: 2700} =
               MonthlyExtraPayments.life_insurance_amount(outstanding_balance)

      assert %Money{amount: 0} = MonthlyExtraPayments.life_insurance_amount(Money.new(0))
    end
  end

  describe "#realty_insurance_amount/1" do
    test "returns the product of realty value by the insurance fee" do
      realty_value = Money.parse!(300_000.0)
      assert %Money{amount: 4800} = MonthlyExtraPayments.realty_insurance_amount(realty_value)
      assert %Money{amount: 0} = MonthlyExtraPayments.realty_insurance_amount(Money.new(0))
    end
  end

  describe "#monthly_administration_amount/0" do
    test "returns the sum of outstanding balance with the administration fees" do
      assert %Money{amount: 0} = MonthlyExtraPayments.monthly_administration_amount()

      assert %Money{amount: 0} = MonthlyExtraPayments.monthly_administration_amount()
    end
  end
end
