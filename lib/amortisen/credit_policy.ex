defmodule Amortisen.CreditPolicy do
  @moduledoc """
  Defines a `CreditPolicy` struct to create amortization tables.
  """

  @type t :: %__MODULE__{
          payment_lack_limit: integer,
          interest_rate: Decimal.t()
        }

  @enforce_keys [:payment_lack_limit, :interest_rate]
  defstruct [:payment_lack_limit, :interest_rate]
end
