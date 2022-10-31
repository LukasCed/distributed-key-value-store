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
  def create(node, table) do
    Logger.debug("Calling create table #{inspect(table)} to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:create, table})
  end

  def get(node, table, key) do
    Logger.debug("Calling get #{inspect(key)} to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:get, table, key})
  end

  def get_all(node, table) do
    Logger.debug("Calling get_all to node #{inspect(node)}")
    GenServer.call({__MODULE__, node}, {:get_all, table})
  end

  def put(node, table, key, value) do
    Logger.debug("Calling put #{inspect(key)}:#{inspect(value)} to node #{inspect(node)}")
    GenServer.cast({__MODULE__, node}, {:put, table, key, value})
  end

  def delete(node, table, key) do
    Logger.debug("Calling delete #{inspect(key)} to node #{inspect(node)}")
    GenServer.cast({__MODULE__, node}, {:delete, table, key})
  end

  ## ------------------------------------------------------------------------------------------------

  ## Server callbacks
  @impl true
  def init(server_name) do
    Logger.debug("Initializing the ETS table #{inspect(server_name)}")
    tables = :ets.new(server_name, [:named_table, read_concurrency: true])
    refs = %{}

    Logger.debug("Joining the cluster with pid #{inspect(self())}")
    :ok = :syn.join(:kv_store, :node, self())

    Logger.debug("Currently known nodes #{inspect(:syn.members(:kv_store, :node))}")
    Logger.debug("Currently known nodes2 #{inspect(Node.list(:known))}")

    {:ok, {tables, refs}}
  end

  @impl true
  def handle_call({:create, name}, _from, {tables, refs}) do
    Logger.debug("Attempting to create table #{inspect(name)}")

    case lookup(tables, name) do
      {:ok, _pid} ->
        {:reply, :exists, {tables, refs}}

      :error ->
        {:ok, pid} = DynamicSupervisor.start_child(KVStore.TableSupervisor, KVStore.Table)
        ref = Process.monitor(pid)
        refs = Map.put(refs, ref, name)
        :ets.insert(tables, {name, pid})
        Logger.debug("Table created")
        {:reply, pid, {tables, refs}}
    end
  end

  @impl true
  def handle_call({:get, table, key}, _from, {tables, refs}) do
    Logger.debug("Attempting to get a record key=#{inspect(key)} from table #{inspect(table)}")
     case lookup(tables, table) do
      {:ok, pid} ->
        case KVStore.Table.get(pid, key) do
          nil -> {:reply, {:error, nil}, {tables, refs}}
          value -> {:reply, {:ok, value}, {tables, refs}}
        end
      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
        {:reply, {:error, :none}, {tables, refs}}
      end
  end

  @impl true
  def handle_call({:get_all, table}, _from, {tables, refs}) do
    Logger.debug("Attempting to get all records from table #{inspect(table)}")
     case lookup(tables, table) do
      {:ok, pid} ->
        case KVStore.Table.get_all(pid) do
          nil -> {:reply, {:error, nil}, {tables, refs}}
          value -> {:reply, {:ok, value}, {tables, refs}}
        end
      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
        {:reply, {:error, :none}, {tables, refs}}
      end
  end

  @impl true
  def handle_cast({:delete, table, key}, {tables, refs}) do
    Logger.debug("Attempting to delete a record key=#{inspect(key)} from table #{inspect(table)}")
     case lookup(tables, table) do
      {:ok, pid} ->
        KVStore.Table.delete(pid, key)
        Logger.debug("Success")
      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
      end

      {:noreply, {tables, refs}}
  end

  @impl true
  def handle_cast({:put, table, key, value}, {tables, refs}) do
    Logger.debug("Attempting to put a record key=#{inspect(key)} value=#{inspect(value)} to table #{inspect(table)}")
     case lookup(tables, table) do
      {:ok, pid} ->
        KVStore.Table.put(pid, key, value)
        Logger.debug("Success")
      :error ->
        Logger.debug("Table #{inspect(table)} does not exist")
      end

      {:noreply, {tables, refs}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    # 6. Delete from the ETS table instead of the map
    {name, refs} = Map.pop(refs, ref)
    :ets.delete(names, name)
    {:noreply, {names, refs}}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in KVStore.Registry: #{inspect(msg)}")
    {:noreply, state}
  end
end
