defmodule KVServer.CoordinatorNode do
  use GenServer
  require Logger
  require UUID

  # ---------------------------- interface ----------------------------


  def perform(op) do
    GenServer.call(__MODULE__, op)
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, {}, name: __MODULE__)

  # ---------------------------- impl ----------------------------

  @impl true
  def init(_) do
    {msg, state} = KVServer.ThreePcCoordinator.read_log()
    if state.tx_active == true and msg == "PHASE23" do
      KVServer.ThreePcCoordinator.transaction("new_tx_id", state.tx_buffer)
    end

    {:ok, %State{tx_active: False, tx_buffer: []}}
  end


  @impl GenServer
  def handle_call({:start_transaction}, _from, %State{tx_active: False, tx_buffer: _}) do
    Logger.debug("Transaction started")
    {:reply, {:ok, "Transaction started\r\n"}, %State{tx_active: True, tx_buffer: []}}
  end

  @impl GenServer
  def handle_call({:end_transaction}, _from, %State{tx_active: True, tx_buffer: tx_list}) do
    Logger.debug("Ending transaction - using 3PC to commit everything")
    KVServer.ThreePcCoordinator.transaction("random_tx_id", tx_list)
    {:reply, {:ok, "Transaction concluded\r\n"}, %State{tx_active: False, tx_buffer: []}}
  end

  # -------------- non-transactional stuff --------------
  @impl GenServer
  def handle_call({:create, table}, _from, %State{tx_active: False, tx_buffer: tx_list}) do
    Logger.debug("Non-transactional create called")
    KVServer.Dao.perform(:create, table)
    {:reply, {:ok, "OK Create\r\n"}, %State{tx_active: False, tx_buffer: tx_list}}
  end

  @impl GenServer
  def handle_call({:put, {table, key, value}}, _from, %State{tx_active: False, tx_buffer: tx_list}) do
    Logger.debug("Non-transactional put called")
    KVServer.Dao.perform(:put, table, key, value)
    {:reply, {:ok, "OK Put\r\n"}, %State{tx_active: False, tx_buffer: tx_list}}
  end

  @impl GenServer
  def handle_call({:get, {table, key}}, _from, %State{tx_active: False, tx_buffer: tx_list}) do
    Logger.debug("Non-transactional get called")
    val = Enum.at(KVServer.Dao.perform(:get, table, key), 0)
    case val do
      {:ok, value} -> {:reply, {:ok, value <> "\r\n"}, %State{tx_active: False, tx_buffer: tx_list}}
      _ -> {:reply, {:ok, "Not found\r\n"}, %State{tx_active: False, tx_buffer: tx_list}}
    end
  end

  @impl GenServer
  def handle_call({:delete, {table, key}}, _from, %State{tx_active: False, tx_buffer: tx_list}) do
    Logger.debug("Non-transactional delete called")
    KVServer.Dao.perform(:delete, table, key)
    {:reply, {:ok, "OK Delete\r\n"}, %State{tx_active: False, tx_buffer: tx_list}}
  end
  # -------------- transactional stuff --------------

  @impl GenServer
  def handle_call({:create, table}, _from, %State{tx_active: True, tx_buffer: tx_list}) do
    Logger.debug("Transactional create called")
    {:reply, {:ok, "OK Buffer create\r\n"}, %State{tx_active: True, tx_buffer: tx_list ++ [{:create, {table}}]}}
  end

  @impl GenServer
  def handle_call({:put, {table, key, value}}, _from, %State{tx_active: True, tx_buffer: tx_list}) do
    Logger.debug("Transactional put called")
    {:reply, {:ok, "OK Buffer Put\r\n"}, %State{tx_active: True, tx_buffer: tx_list ++ [{:put, {table, key, value}}]}}
  end

  @impl GenServer
  def handle_call({:get, {table, key}}, _from, %State{tx_active: True, tx_buffer: tx_list}) do
    Logger.debug("Transactional get called")
    {:reply, {:ok, "OK Buffer Get\r\n"}, %State{tx_active: True, tx_buffer: tx_list ++ [{:get, {table, key}}]}}
  end

  @impl GenServer
  def handle_call({:delete, {table, key}}, _from, %State{tx_active: True, tx_buffer: tx_list}) do
    Logger.debug("Transactional delete called")
    {:reply, {:ok, "OK Buffer Delete\r\n"}, %State{tx_active: True, tx_buffer: tx_list ++ [{:delete, {table, key}}]}}
  end


end
