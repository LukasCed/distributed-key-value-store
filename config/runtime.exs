import Config

config :kv_store, :routing_table, [{?a..?z, node()}]

# if config_env() == :prod do
#   config :kv_store, :routing_table, [
#     {?a..?m, :"foo@DESKTOP-G5M07CN"},
#     {?n..?z, :"bar@DESKTOP-G5M07CN"}
#   ]
# end
