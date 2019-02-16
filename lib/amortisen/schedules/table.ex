defmodule Amortisen.Schedules.Table do
  @moduledoc """
  Represents a complete schedule table.
  It's composable by a list of `Line` structs and a total of taxes.
  """

  alias Amortisen.Schedules.Line

  @type t :: %__MODULE__{
          schedule_lines: nonempty_list(Line.t()),
          financial_transaction_taxes: Money.t()
        }

  @enforce_keys [:schedule_lines, :financial_transaction_taxes]
  defstruct [:schedule_lines, :financial_transaction_taxes]
end
