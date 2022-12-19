defmodule KVServer.ThreePcCoordinator do
  require Logger

  def transaction(tx_id, query_list) do
    Logger.debug("Sending init from the coordinator")
    # retransmit on timeout?
    acks = broadcast(:init, {tx_id, query_list})

    if Enum.all?(acks, fn x -> x == :agree end) do
      write_log(tx_id, true, query_list, "PHASE12")
      Logger.debug("Sending prepare from the coordinator")
      # retransmit on timeout?
      acks = broadcast(:prepare, tx_id)

      if Enum.all?(acks, fn x -> x == :agree end) do
        write_log(tx_id, true, query_list, "PHASE23")
        Logger.debug("Sending commit from the coordinator")
        # retransmit on timeout?
        acks = broadcast(:commit, tx_id)

        if Enum.all?(acks, fn x -> x == :agree end) do
          write_log(tx_id, false, query_list, "COMPLETE")
          :commit_success
        end
      end
    else
      Logger.debug("Sending abort from the coordinator")
      # retransmit on timeout?
      broadcast(:abort, tx_id)
      write_log(tx_id, false, [], "COMPLETE")
      :commit_failure
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
      {"None", %State{tx_active: False, tx_buffer: []}}
    else
      {:ok, logs} = File.read(file_path)
      contents = List.last(logs |> String.split("\r\n", trim: true))
      [binary_term, msg] = contents |> String.split(";", trim: true)
      {msg, :erlang.binary_to_term(binary_term)}
    end
  end
end
