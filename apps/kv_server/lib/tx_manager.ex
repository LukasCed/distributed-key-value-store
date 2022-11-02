defmodule KVServer.TxManager do
  use GenServer
  require Logger
  require UUID

    # ---------------------------- interface ----------------------------

  def start_transaction() do
    GenServer.call(__MODULE__, :transaction_start)
  end

  def end_transaction() do
    GenServer.call(__MODULE__, :transaction_end)
  end

  def get_txid() do
    GenServer.call(__MODULE__, :get_txid)
  end

  # there is a transaction - wait for acks
  def manage_transaction(:transaction, fnct) do
    GenServer.call(__MODULE__, {:transaction, fnct})
  end

  # there is no transaction - dont wait for acks
  def manage_transaction(:no_transaction, fnct) do
    GenServer.call(__MODULE__, {:no_transaction, fnct})
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, {}, name: __MODULE__)

  # ---------------------------- impl ----------------------------

  @impl GenServer
  def handle_call(:transaction_start, {pid, _}, {txids, participants}) do
    txid = UUID.uuid1()
    # calling process linked to a txid
    txids = Map.put(txids, pid, txid)
    Logger.debug("Transaction #{inspect(txid)} created from #{inspect(pid)} started")
    {:reply, {:ok, txid}, {txids, participants}}
  end

  @impl GenServer
  def handle_call(:transaction_end, {pid, _}, {txids, participants}) do
    txid = Map.get(txids, pid)
    Logger.debug("Ending #{inspect(txid)} transaction in process #{inspect(pid)}")
    # deleting transaction info
    txids = Map.delete(txids, pid)

    # get how many participants expected
    p_count = Map.get(participants, txid)

    # phase 1: ask if nodes are prepared to commit. sends to everyone
    # (assumes nodes will answer truthfully if they have a transaction with that id)
    acks = KVStore.Router.route_all(KVStore.Registry, :prepare, [txid])
    # @todo filter those who sent :yes
    # @todo make so that nodes send their ids together with acks so you know only those who needed to ack'ed
    Logger.debug("Received acks when preparing #{inspect(acks)}")
    # phase 2: send commit
    case length(acks) == p_count and :no not in acks do
      # ttl to avoid infinte loop
      true ->
        case commit(txid, p_count, 10) do
          :commit_success ->
            Logger.debug("#{inspect(txid)} was successfuly commited")
            {:reply, {:ok, txid}, {txids, participants}}
          :commit_fail ->
            Logger.debug("Failed the commit step in #{inspect(txid)}")
            {:reply, {:commit_fail, txid}, {txids, participants}}
        end
      _ ->
        Logger.debug("Failed the prepare step in #{inspect(txid)}")
        {:reply, {:prepare_fail, txid}, {txids, participants}}
    end
  end

  @impl GenServer
  def handle_call(:get_txid, {pid, _}, {txids, participants}) do
    # is there a txid linked to my pid?
    txid = Map.get(txids, pid)
    {:reply, {:ok, txid}, {txids, participants}}
  end

  @impl GenServer
  def handle_call({:transaction, fnct}, {pid, _}, {txids, participants}) do
    # handle transaction, wait for acks and mark how many nodes participated in the transaction
    case Map.get(txids, pid) do
      nil -> raise "Attempting to handle a transaction but process #{pid} has no transactions associated"
      txid ->
        # collect info of how many nodes acknowledged this operation. keep track of the maximum value
        # the same value will be used later to wait for acks to commit
        acks = fnct.(txid)
        acks = if is_list(acks), do: acks, else: [acks]
        prev_acks = Map.get(participants, txid, 0)
        participants = Map.put(participants, txid, max(prev_acks, length(acks)))

        Logger.debug("Participants count: #{inspect(participants)}")
        {:reply, {:ok, txid}, {txids, participants}}
    end
  end

  @impl GenServer
  def handle_call({:no_transaction, fnct}, _, state) do
    {:reply, fnct.(nil), state}
  end

  defp commit(txid, expected_acks, ttl) do
    acks = KVStore.Router.route_all(KVStore.Registry, :commit, [txid])
    Logger.debug("Received acks when commiting #{inspect(acks)}, expected #{inspect(expected_acks)}")

    if ttl > 0 do
      case length(acks) do
        ^expected_acks -> :commit_success
        _ -> commit(txid, expected_acks, ttl - 1)
      end
    else
      :commit_fail
    end
  end

  @impl GenServer
  def init(_arg) do
    Logger.debug("TX manager started")
    # tx id linked to pids
    txids = %{}
    # which participants are in the tx
    participants = %{}
    {:ok, {txids, participants}}
  end
end
