defmodule KVServer.ThreePcCoordinator do
  require Logger

  def init(tx_id, query_list) do
    Logger.debug("Sending init from the coordinator")
    # retransmit on timeout?
    acks = KVServer.ThreePcCoordinator.broadcast_init(tx_id, query_list)

    if Enum.all?(acks, fn x -> x == :agree end) do
      prepare(tx_id, query_list)
    else
      Logger.debug("Sending abort from the coordinator")
      # retransmit on timeout?
      KVServer.ThreePcCoordinator.broadcast_abort(tx_id)
      write_log(tx_id, false, [], "COMPLETE")
      :commit_failure
    end
  end

  def prepare(tx_id, query_list) do
    write_log(tx_id, true, query_list, "PHASE12")
    Logger.debug("Sending prepare from the coordinator")
    # retransmit on timeout?
    acks = KVServer.ThreePcCoordinator.broadcast_prepare(tx_id)

    if Enum.all?(acks, fn x -> x == :agree end) do
      commit(tx_id, query_list)
    end
  end

  def commit(tx_id, query_list) do
    write_log(tx_id, true, query_list, "PHASE23")
    Logger.debug("Sending commit from the coordinator")
    # retransmit on timeout?
    acks = KVServer.ThreePcCoordinator.broadcast_commit(tx_id)

    if Enum.all?(acks, fn x -> x == :agree end) do
      write_log(tx_id, false, query_list, "COMPLETE")
      :commit_success
    end
  end

  defp write_log(_tx_id, tx_active, query_list, msg) do
    state = %State{tx_active: tx_active, tx_buffer: query_list}
    Logger.debug("Writing #{inspect(msg)} log from coordinator")
    mkdir_if_not_exists("coordinator")

    File.write(
      "db_logs/coordinator/tx_manager_log",
      :erlang.term_to_binary(state) <> ";" <> msg <> "\r\n",
      [:append]
    )
  end

  def broadcast_init(tx_id, query_list) do
    broadcast(:init, {tx_id, query_list})
  end

  def broadcast_prepare(tx_id) do
    broadcast(:prepare, tx_id)
  end

  def broadcast_commit(tx_id) do
    broadcast(:commit, tx_id)
  end

  def broadcast_abort(tx_id) do
    broadcast(:abort, tx_id)
  end

  def broadcast(msg, args) do
    KVStore.Router.route_all(:transaction, msg, args)
  end

  defp mkdir_if_not_exists(path) do
    dir_path = Path.absname("db_logs" <> "/" <> to_string(path))
    File.mkdir_p(dir_path)
  end

  def read_log() do
    mkdir_if_not_exists("db_logs/coordinator")
    file_path = Path.absname("db_logs/coordinator/tx_manager_log")
    Logger.debug("Loading state from #{inspect(file_path)} in the coordinator node")

    if not File.exists?(file_path) do
      Logger.debug("Prev. state not found")
      {"None", %State{tx_active: False, tx_buffer: []}}
    else
      {:ok, logs} = File.read(file_path)
      contents = List.last(logs |> String.split("\r\n", trim: true))
      [binary_term, msg] = contents |> String.split(";", trim: true)
      state = :erlang.binary_to_term(binary_term)
      Logger.debug("Loaded up state #{inspect(state)}")
      {msg, state}
    end
  end
end
