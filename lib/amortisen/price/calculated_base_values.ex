defmodule Amortisen.Price.CalculatedBaseValues do
  @moduledoc """
  Reprensets the calculated base values for Price table.
  """

  @typedoc """
  ---
  start_at: Data de pagamento da primeira parcela
  ---
  outstanding_balalce: Saldo devedor (Valor solicitado com juros e taxas)
  ---
  regular_payment_amount: Valor da parcela (Valor fixo para sistema Price)
  ---
  """
  @type t :: %__MODULE__{
          start_at: Date.t(),
          outstanding_balance: Money.t(),
          regular_payment_amount: Money.t()
        }

  defstruct [:start_at, :outstanding_balance, :regular_payment_amount]
end
