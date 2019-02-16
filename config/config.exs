# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :amortisen, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:amortisen, :key)
#
# You can also configure a third-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"

config :money,
  # this allows you to do Money.new(100)
  default_currency: :BRL,
  # change the default thousands separator for Money.to_string
  separator: "",
  # change the default decimal delimeter for Money.to_string
  delimiter: "",
  # don’t display the currency symbol in Money.to_string
  symbol: false,
  # position the symbol
  symbol_on_right: false,
  # add a space between symbol and number
  symbol_space: false,
  # don’t display the remainder or the delimeter
  fractional_unit: true
