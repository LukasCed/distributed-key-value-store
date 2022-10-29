import Config

config :first_assignment, :routing_table, [{?a..?z, node()}]

if config_env() == :prod do
  config :first_assignment, :routing_table, [
    {?a..?m, :"foo@DESKTOP-G5M07CN"},
    {?n..?z, :"bar@DESKTOP-G5M07CN"}
  ]
end
