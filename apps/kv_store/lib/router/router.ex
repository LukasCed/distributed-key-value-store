defmodule KVStore.Router do
  require Logger

  # i.e. :transaction, :init, {tx_id, query_list}
  # :no_transaction, :put, {table, key, value}

  def route_all(type, msg, args) do
    nodes = nodes()
    Logger.debug("Routing to nodes: #{inspect(nodes)} from: #{inspect(node())}")

    for node <- nodes, do: KVStore.Node.perform_op(type, node, msg, args)
  end

  def nodes do
    for name <- Node.list([:known, :visible]), name != :nonode@nohost, do: name
  end
end
