defmodule KVStore.Registry do
  use GenServer
  require Logger

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    server = Keyword.fetch!(opts, :name)
    Logger.debug("Starting registry: #{inspect(server)}")
    GenServer.start_link(__MODULE__, server, opts)
  end

  def lookup(tables, table) do
    Logger.debug("Looking up #{inspect(table)} in #{inspect(tables)}")
    # Check if there is a table existing
    case :ets.lookup(tables, table) do
      [{^table, pid}] ->
        Logger.debug("Table exists")
        {:ok, pid}

      [] ->
        Logger.debug("Table does not exist")
        :error
    end
  end

  @doc """
  Ensures there is a table associated with the given `name` in `server`.
  """
  def create(node, table, tx) do
    Logger.debug("Calling create table #{inspect(table)} to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:create, table, tx})
  end

  def get(node, table, key, tx) do
    Logger.debug("Calling get #{inspect(key)} to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:get, table, key, tx})
  end

  # for debug purposes
  def get_all(node, table) do
    Logger.debug("Calling get_all to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:get_all, table})
  end

  # transactional put - need to make it a call not cast
  def put(node, table, key, value, {:transaction, txid}) do
    Logger.debug("Calling put #{inspect(key)}:#{inspect(value)} to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:put, table, key, value, {:transaction, txid}})
  end

  def put(node, table, key, value, tx) do
    Logger.debug("Calling put #{inspect(key)}:#{inspect(value)} to node #{inspect(node)}")
    GenServer.cast({__MODULE__, node}, {:put, table, key, value, tx})
  end

  # transactional delete - need to make it a call not cast
  def delete(node, table, key, {:transaction, txid}) do
    Logger.debug("Calling delete #{inspect(key)} to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:delete, table, key, {:transaction, txid}})
  end

  def delete(node, table, key, tx) do
    Logger.debug("Calling delete #{inspect(key)} to node #{inspect(node)}")
    GenServer.cast({__MODULE__, node}, {:delete, table, key, tx})
  end

  def prepare(node, txid) do
    Logger.debug("Received a prepare request")
    GenServer.call({__MODULE__, node}, {:prepare, txid})
  end

  def commit(node, txid) do
    Logger.debug("Received a commit request")
    GenServer.call({__MODULE__, node}, {:commit, txid})
  end

  ## ------------------------------------------------------------------------------------------------

  ## Server callbacks
  @impl true
  def init(server_name) do
    Logger.debug("Initializing the ETS table #{inspect(server_name)}")
    tables = :ets.new(server_name, [:named_table, read_concurrency: true])
    refs = %{}
    txs = %{}

    Logger.debug("Joining the cluster with pid #{inspect(self())}")
    :ok = :syn.join(:kv_store, :node, self())

    # Logger.debug("Currently known nodes #{inspect(:syn.members(:kv_store, :node))}")
    Logger.debug("Currently known nodes #{inspect(Node.list(:known))}")

    {:ok, {tables, refs, txs}}
  end

  ##-------transactional-------

  # transactional
  @impl true
  def handle_call({:delete, table, key, {:transaction, txid}}, _from, {tables, refs, txs}) do
    Logger.debug("Writing down delete key=#{inspect(key)} in a transaction #{inspect(txid)}")
    tx_list = Map.get(txs, txid) || []
    txs = Map.put(txs, txid, [{:do_delete, [table, key]} | tx_list])
    {:reply, :ok, {tables, refs, txs}}
  end

  # transactional
  @impl true
  def handle_call({:create, name, {:transaction, txid}}, _from, {tables, refs, txs}) do
    Logger.debug(
      "Writing down creation of table #{inspect(name)} in a transaction #{inspect(txid)}"
    )

    tx_list = Map.get(txs, txid) || []
    txs = Map.put(txs, txid, [{:do_create, [name]} | tx_list])
    {:reply, :ok, {tables, refs, txs}}
  end

  # transactional
  @impl true
  def handle_call({:get, table, key, {:transaction, txid}}, _from, {tables, refs, txs}) do
    Logger.debug("Writing down get key=#{inspect(key)} in a transaction #{inspect(txid)}")
    tx_list = Map.get(txs, txid) || []
    txs = Map.put(txs, txid, [{:do_get, [table, key]} | tx_list])
    {:reply, :ok, {tables, refs, txs}}
  end

  # transactional
  @impl true
  def handle_call({:put, table, key, value, {:transaction, txid}}, _from, {tables, refs, txs}) do
    Logger.debug("Writing down put key=#{inspect(key)} in a transaction #{inspect(txid)}")
    tx_list = Map.get(txs, txid) || []
    txs = Map.put(txs, txid, [{:do_put, table, [key, value]} | tx_list])
    {:reply, :ok, {tables, refs, txs}}
  end

  @impl true
  def handle_call({:prepare, txid}, _from, {tables, refs, txs}) do
    # might do backup to disks

    # some trivial validaitons done
    case txid in Map.keys(txs) do
      false -> {:reply, :no, {tables, refs, txs}}
      true -> {:reply, :yes, {tables, refs, txs}}
    end

    # some other validations, likeis the data non conflicting etc
  end


  @impl true
  def handle_call({:commit, txid}, _from, {tables, refs, txs}) do
    Logger.debug("Commiting")
    tx_list = Map.get(txs, txid)
    for {command, args} <- tx_list, do: apply(KVStore.Registry, command, [node() | args] ++ [:no_transaction])

    txs = Map.delete(txs, txid)

    Logger.debug("Transaction commited")
    {:reply, :ok, {tables, refs, txs}}
  end

  ## -------nontransactional-------
  @impl true
  def handle_call({:create, name, :no_transaction}, _from, {tables, refs, _}) do
    Logger.debug("Attempting to create table #{inspect(name)}")
    do_create(tables, refs, name)
  end

  @impl true
  def handle_call({:get, table, key, :no_transaction}, _from, {tables, refs, _}) do
    Logger.debug("Attempting to get a record key=#{inspect(key)} from table #{inspect(table)}")
    do_get(tables, refs, table, key)
  end

  @impl true
  def handle_call({:get_all, table}, _from, {tables, refs, txs}) do
    Logger.debug("Attempting to get all records from table #{inspect(table)}")

    case lookup(tables, table) do
      {:ok, pid} ->
        case KVStore.Table.get_all(pid) do
          nil -> {:reply, {:error, nil}, {tables, refs, txs}}
          value -> {:reply, {:ok, value}, {tables, refs, txs}}
        end

      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
        {:reply, {:error, :none}, {tables, refs, txs}}
    end
  end

  @impl true
  def handle_cast({:delete, table, key, :no_transaction}, {tables, refs, _}) do
    Logger.debug("Attempting to delete a record key=#{inspect(key)} from table #{inspect(table)}")

    do_delete(tables, table, key)
    {:noreply, {tables, refs, %{}}}
  end


  @impl true
  def handle_cast({:put, table, key, value, :no_transaction}, {tables, refs, _}) do
    Logger.debug(
      "Attempting to put a record key=#{inspect(key)} value=#{inspect(value)} to table #{inspect(table)}"
    )
    do_put(tables, table, key, value)
    {:noreply, {tables, refs, %{}}}
  end

  def do_create(tables, refs, name) do
    case lookup(tables, name) do
      {:ok, _pid} ->
        {:reply, :exists, {tables, refs, %{}}}

      :error ->
        {:ok, pid} = DynamicSupervisor.start_child(KVStore.TableSupervisor, KVStore.Table)
        ref = Process.monitor(pid)
        refs = Map.put(refs, ref, name)
        :ets.insert(tables, {name, pid})
        Logger.debug("Table created")
        {:reply, pid, {tables, refs, %{}}}
    end
  end

  def do_get(tables, refs, table, key) do
    case lookup(tables, table) do
      {:ok, pid} ->
        case KVStore.Table.get(pid, key) do
          nil -> {:reply, {:error, nil}, {tables, refs, %{}}}
          value -> {:reply, {:ok, value}, {tables, refs, %{}}}
        end

      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
        {:reply, {:error, :none}, {tables, refs, %{}}}
    end
  end

  def do_delete(tables, table, key) do
    case lookup(tables, table) do
      {:ok, pid} ->
        KVStore.Table.delete(pid, key)
        Logger.debug("Success")

      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
    end
  end

  def do_put(tables, table, key, value) do
    case lookup(tables, table) do
      {:ok, pid} ->
        KVStore.Table.put(pid, key, value)
        Logger.debug("Success")

      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs, _}) do
    # 6. Delete from the ETS table instead of the map
    {name, refs} = Map.pop(refs, ref)
    :ets.delete(names, name)
    {:noreply, {names, refs, %{}}}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in KVStore.Registry: #{inspect(msg)}")
    {:noreply, state}
  end
end
