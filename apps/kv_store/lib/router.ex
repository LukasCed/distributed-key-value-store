defmodule KVStore.Router do
  require Logger
  @doc """
  Dispatch the given `mod`, `fun`, `args` request
  to the appropriate node based on the `key`.
  """
  def route(key, mod, fun, args) do
    Logger.debug("Routing request to one of the nodes #{inspect(nodes())}")
    # Get the first byte of the binary
    first = :binary.first(key)

    # Try to find an entry in the table() or raise
    entry = table(first) || no_entry_error(key)

    # # If the entry node is the current node
    # # not sure when self() and when node()
    # if entry == self() do
    #   apply(mod, fun, args)
    # else
    #   spawn_process(entry, key, mod, fun, args)
    # end

    apply(mod, fun, [entry | args])
  end

  def route_all(mod, fun, args) do
    # route to everything
    # node() or node?
    nodes = nodes()
    Logger.debug("Routing to nodes: #{inspect(nodes)} from: #{inspect(node())}")

    nodes |> Enum.each(fn node -> apply(mod, fun, [node | args]) end)
  end

  # defp spawn_process(node, key, mod, fun, args) do
  #   node
  #   |> Task.Supervisor.async(KVStore.Router, :route, [key, mod, fun, args])
  #   |> Task.await()
  # end

  defp no_entry_error(key) do
    raise "could not find entry for #{inspect(key)} in nodes #{inspect(nodes())}"
  end

  @doc """
  The routing table.
  @todo fix to consistent hashing or rehash
  """
  def table(char) do
    case length(nodes()) do
      x when x > 0 ->
        hash = :erlang.phash2(char)
        slot = rem(hash, x)
        Enum.at(nodes(), slot)

      x ->
        raise "unexpected number of nodes in hashing table: #{x}"
    end
  end

  def nodes do
    for name <- Node.list(:known), name != :nonode@nohost, do: name
  end
end
