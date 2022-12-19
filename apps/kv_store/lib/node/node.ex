defmodule KVStore.Node do
  use GenServer
  require Logger

  @doc """
  Starts the node.
  """
  def start_link(opts) do
    server = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, server, name: __MODULE__)
  end

  # -------

  def perform_op(type, node, msg, args) do
    GenServer.call({__MODULE__, node}, {type, node, msg, args})
  end


  ## --------------------------------- Server callbacks ---------------------------------
  @impl true
  def init(node) do
    Logger.debug("Starting node: #{inspect(node)}")
    %{current_tx: tx} = KVStore.ThreePcParticipant.read_log(node)

    if tx != nil and tx.status == :prepare do
      KVStore.ThreePcParticipant.commit(tx.query_list, node)
    end

    {:ok, %{current_tx: nil}}
  end

  # ---- transaction ----

  @impl true
  def handle_call({:transaction, node, msg, {tx_id, queries}}, _from, state) do
    if valid(queries) do
      state = KVStore.ThreePcParticipant.transaction(msg, node, {tx_id, queries}, state)
      {:reply, :agree, state}
    end
  end

  @impl true
  def handle_call({:no_transaction, node, db_op, args}, _from, state) do
    result = KVStore.Database.perform_op(db_op, to_string(node), args)
    {:reply, result, state}
  end

  defp valid(_queries) do
    true
  end
end
