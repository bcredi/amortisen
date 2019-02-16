defmodule Amortisen.FinancialTransactionTaxesTest do
  use ExUnit.Case

  alias Amortisen.FinancialTransactionTaxes

  describe "#amortization_tax_amount/2" do
    test "return the amount of rule of three" do
      assert %Money{amount: 559} =
               FinancialTransactionTaxes.amortization_tax_amount(Money.new(89_259), 30)

      assert %Money{amount: 339} =
               FinancialTransactionTaxes.amortization_tax_amount(Money.new(89_259), 0)
    end

    test "returns zero when amortization is zero" do
      assert %Money{amount: 0} =
               FinancialTransactionTaxes.amortization_tax_amount(Money.new(0), 30)
    end
  end

  describe "#compute_funded_tax_amount/2" do
    test "return the amount of funded taxes using a sum of all amortizations taxes" do
      assert %Money{amount: 361_895} =
               FinancialTransactionTaxes.compute_funded_tax_amount(
                 Money.new(10_500_000),
                 Money.new(349_837)
               )
    end

    test "return zero when loan amount is zero" do
      assert %Money{amount: 0} =
               FinancialTransactionTaxes.compute_funded_tax_amount(
                 Money.new(0),
                 Money.new(349_837)
               )
    end

    test "return zero when amortizations taxes are zero" do
      assert %Money{amount: 0} =
               FinancialTransactionTaxes.compute_funded_tax_amount(
                 Money.new(10_500_000),
                 Money.new(0)
               )
    end
  end
end
