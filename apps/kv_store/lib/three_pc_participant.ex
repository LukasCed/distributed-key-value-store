defmodule KVStore.ThreePcParticipant do
  # problem: how to define blocking waiting? i.e. in :prepare calls
  use GenServer
  require Logger

  @doc """
  Starts the node.
  """
  def start_link(opts) do
    server = Keyword.fetch!(opts, :name)
    Logger.debug("Starting 3PC participant: #{inspect(server)}")
    GenServer.start_link(__MODULE__, server, opts)
  end

  # -------

  def transaction(:init, node, tx, tx_id) do
    GenServer.call({__MODULE__, node}, {:init, tx_id, tx})
  end

  def transaction(:prepare, node, tx_id) do
    GenServer.call({__MODULE__, node}, {:prepare, tx_id})
  end

  def transaction(:commit, node, tx_id) do
    GenServer.call({__MODULE__, node}, {:commit, tx_id})
  end

  def transaction(:abort, node, tx_id) do
    GenServer.call({__MODULE__, node}, {:abort, tx_id})
  end


  ## --------------------------------- Server callbacks ---------------------------------
  # @type t() :: %__MODULE__{
  #   tx_id: String.t(),
  #   tx_info: [],
  # }
  defmodule State do
    defstruct current_txs: %{}
  end

  defmodule TxInfo do
    defstruct [:status, :query_list]
  end

  @impl true
  def init(_) do
    {:ok, %State{current_txs: %{}}}
  end

  @impl true
  def handle_call({:init, tx_id, tx}, _from, state = %State{current_txs: current_txs}) do
    if validate(tx_id, tx, current_txs) do
      # write in memory for fast checkup
      new_tx_info = %{ tx_id => %TxInfo{ status: :init, query_list: [tx] }}
      state = %State{ state | current_txs: Map.merge(current_txs, new_tx_info)}
      # write in disk for durability
      write_log(tx_id, tx, "phase12")
      {:reply, :agree, state}
    end

    :abort
  end

  @impl true
  def handle_call({:prepare, tx_id}, _from, state = %State{current_txs: current_txs}) do
    if exists_transaction(tx_id, current_txs, :init) do
      # write in memory for fast checkup
      %TxInfo{ status: :init, query_list: query_list } = Map.get(current_txs, tx_id)
      new_tx_info = %{ tx_id => %TxInfo{ status: :prepare, query_list: query_list }}
      state = %State{ state | current_txs: Map.merge(current_txs, new_tx_info)}
      # write in disk for durability
      write_log(tx_id, "", "phase23")
      {:reply, :agree, state}
    end
  end

  @impl true
  def handle_call({:commit, tx_id}, _from, state = %State{current_txs: current_txs}) do
    if exists_transaction(tx_id, current_txs, :prepare) do
      # get query from memory
      %TxInfo{ status: :prepare, query_list: query_list } = Map.get(current_txs, tx_id)
      # delete
      state = %State{ state | current_txs: Map.delete(current_txs, tx_id)}

      # actually commit
      write_commit(tx_id, query_list)
      {:reply, :agree, state}
    end
  end

  @impl true
  def handle_call({:abort, tx_id}, _from, state = %State{current_txs: current_txs}) do

  end

  # -------- util functions
  defp exists_transaction(tx_id, current_txs, status) do
    case Map.get(current_txs, tx_id) do
      nil -> false
      val -> status == :any or val.status == status
    end
  end

  defp validate(tx_id, _tx, current_txs) do
    not exists_transaction(tx_id, current_txs, :any)
  end

  defp write_log(tx_id, tx, msg) do
    File.write("tx_participant_log", tx_id <> ";" <> to_string_a(tx) <> ";" <> msg <> "\r\n", [:append])
  end

  defp write_commit(tx_id, tx) do
    File.write("tx_participant_commit", tx_id <> ";" <> to_string_a(tx) <> "\r\n", [:append])
  end

  defp to_string_a(tx) do
    "transaction"
  end
end
