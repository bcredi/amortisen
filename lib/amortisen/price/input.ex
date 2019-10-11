defmodule Amortisen.Price.Input do
  @type t :: %__MODULE__{
          number_of_days_until_first_payment: Date.t(),
          user_requested_value: Money.t(),
          operation_cost_value: Money.t(),
          payment_term: integer()
        }

  @enforce_keys [
    :number_of_days_until_first_payment,
    :user_requested_value,
    :operation_cost_value,
    :payment_term
  ]
  defstruct [
    :number_of_days_until_first_payment,
    :user_requested_value,
    :operation_cost_value,
    :payment_term
  ]
end
