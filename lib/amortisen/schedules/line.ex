defmodule Amortisen.Schedules.Line do
  @moduledoc """
  Represents a line of a schedule table.
  """

  @type t :: %__MODULE__{
          date: Date.t(),
          interest: Money.t(),
          principal: Money.t(),
          life_insurance: Money.t(),
          realty_insurance: Money.t(),
          outstanding_balance: Money.t()
        }

  @enforce_keys [
    :date,
    :interest,
    :principal,
    :life_insurance,
    :realty_insurance,
    :outstanding_balance
  ]
  defstruct [
    :date,
    :interest,
    :principal,
    :life_insurance,
    :realty_insurance,
    :outstanding_balance
  ]
end
