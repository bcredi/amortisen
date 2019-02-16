defmodule Amortisen.Schedules.Line do
  @moduledoc """
  Represents a line of a schedule table.
  """

  @type t :: %__MODULE__{
          date: Date.t(),
          interest: Money.t(),
          principal: Money.t(),
          monthly_extra_payment: Money.t(),
          outstanding_balance: Money.t()
        }

  @enforce_keys [:date, :interest, :principal, :monthly_extra_payment, :outstanding_balance]
  defstruct [:date, :interest, :principal, :monthly_extra_payment, :outstanding_balance]
end
