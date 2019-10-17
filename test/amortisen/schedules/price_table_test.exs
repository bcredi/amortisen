defmodule Amortisen.Schedules.PriceTableTest do
  use ExUnit.Case

  alias Amortisen.Price.Input
  alias Amortisen.CreditPolicy
  alias Amortisen.Schedules.{Line, PriceTable}

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

  describe "#build_schedule_table/2" do
    test "returns the correct table given a credit policy that has financed iof" do
      today = Timex.today()

      line_values = [
        {0, 31_356_78, 0_00, 0_00},
        {1, 29_014_72, 402_33, 682_82},
        {2, 28_323_43, 393_86, 691_29},
        {3, 27_623_57, 385_29, 699_86},
        {4, 26_915_03, 376_61, 708_54},
        {5, 26_197_71, 367_83, 717_32},
        {6, 25_471_49, 358_93, 726_22},
        {7, 24_736_27, 349_93, 735_22},
        {8, 23_991_93, 340_81, 744_34},
        {9, 23_238_36, 331_58, 753_57},
        {10, 22_475_45, 322_24, 762_91},
        {11, 21_703_08, 312_78, 772_37},
        {12, 20_921_13, 303_20, 781_95},
        {13, 20_129_48, 293_50, 791_65},
        {14, 19_328_02, 283_69, 801_46},
        {15, 18_516_62, 273_75, 811_40},
        {16, 17_695_16, 263_69, 821_46},
        {17, 16_863_51, 253_50, 831_65},
        {18, 16_021_55, 243_19, 841_96},
        {19, 15_169_15, 232_75, 852_40},
        {20, 14_306_18, 222_18, 862_97},
        {21, 13_432_51, 211_48, 873_67},
        {22, 12_548_00, 200_64, 884_51},
        {23, 11_652_53, 189_68, 895_47},
        {24, 10_745_95, 178_57, 906_58},
        {25, 9_828_13, 167_33, 917_82},
        {26, 8_898_93, 155_95, 929_20},
        {27, 7_958_21, 144_43, 940_72},
        {28, 7_005_82, 132_76, 952_39},
        {29, 6_041_62, 120_95, 964_20},
        {30, 5_065_47, 109_00, 976_15},
        {31, 4_077_21, 96_89, 988_26},
        {32, 3_076_70, 84_64, 1_000_51},
        {33, 2_063_78, 72_23, 1_012_92},
        {34, 1_038_30, 59_67, 1_025_48},
        {35, 0_10, 46_95, 1_038_20},
        {36, 0, 34_08, 1_051_07}
      ]

      expected_schedule_lines =
        line_values
        |> Enum.map(fn {index, outstanding_balance, interest, amortization} ->
          %Line{
            date: shift_schedule_line_date(today, @numbers_of_days_until_first_payment, index),
            outstanding_balance: Money.new(outstanding_balance),
            principal: Money.new(amortization),
            interest: Money.new(interest),
            life_insurance: @zero_money,
            realty_insurance: @zero_money
          }
        end)

      # IOF
      expected_financial_transaction_taxes = Money.new(972_72)

      table_result = PriceTable.build_schedule_table(@price_input, @credit_policy)

      assert expected_financial_transaction_taxes == table_result.financial_transaction_taxes
      assert_lines(expected_schedule_lines, table_result.schedule_lines)
    end
  end

  def assert_lines([expected_line | []], [result_line | []]) do
    assert expected_line == result_line
  end

  def assert_lines([expected_line | expected_lines], [result_line | result_lines]) do
    assert expected_line == result_line
    assert_lines(expected_lines, result_lines)
  end

  def shift_schedule_line_date(date, lack, shifted_month_amount) do
    if shifted_month_amount == 0 do
      date
    else
      shifted_months = div(lack, 30) + shifted_month_amount - 1
      Timex.shift(date, months: shifted_months)
    end
  end
end
