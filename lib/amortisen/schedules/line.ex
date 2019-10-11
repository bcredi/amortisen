defmodule Amortisen.Schedules.Line do
  @moduledoc """
  Represents a line of a schedule table.
  """

  @typedoc """
  ---
  date: Data de pagamento da parcela
  ---
  interest: Juros reference a essa parcela
  ---
  principal: Valor amortizado // Installment value
  ---
  life_insurance: Valor do Seguro de Vida
  ---
  realty_insurance: Valor do Seguro do Imovel
  ---
  outstanding_balalce: Saldo devedor
  ---
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
