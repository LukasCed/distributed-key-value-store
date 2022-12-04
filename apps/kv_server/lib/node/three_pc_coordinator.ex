defmodule KVServer.ThreePcCoordinator do

  require Logger

  def transaction(tx_id, query_list) do
    Logger.debug("Sending init from the coordinator")
    acks = broadcast(:init, {tx_id, query_list}) # retransmit on timeout?
    if Enum.all?(acks, fn x -> x == :agree end) do
      write_phase12(tx_id)
      Logger.debug("Sending prepare from the coordinator")
      acks = broadcast(:prepare, tx_id)  # retransmit on timeout?
      if Enum.all?(acks, fn x -> x == :agree end) do
        write_phase23(tx_id)
        Logger.debug("Sending commit from the coordinator")
        acks = broadcast(:commit, tx_id)  # retransmit on timeout?
        if Enum.all?(acks, fn x -> x == :agree end) do
          write_complete(tx_id)
          :commit_success
        end
      end
    end

    Logger.debug("Sending abort from the coordinator")
    broadcast(:abort, tx_id)  # retransmit on timeout?
    write_complete(tx_id)
    :commit_failure
  end

  defp write_phase12(_state) do
    Logger.debug("Writing phase12 log from coordinator")
    mkdir_if_not_exists("coordinator")
    File.write("db_logs/coordinator/tx_manager_log", "state here" <> ";" <> "PHASE12" <> "\r\n", [:append])
  end

  defp write_phase23(_state) do
    Logger.debug("Writing phase23 log from coordinator")
    mkdir_if_not_exists("coordinator")
    File.write("db_logs/coordinator/tx_manager_log", "state here" <> ";" <> "PHASE23" <> "\r\n", [:append])
  end

  defp write_complete(_state) do
    Logger.debug("Writing complete log from coordinator")
    mkdir_if_not_exists("coordinator")
    File.write("db_logs/coordinator/tx_manager_log", "state here" <> ";" <> "COMPLETE" <> "\r\n", [:append])
  end

  def broadcast(msg, args) do
    KVStore.Router.route_all(:transaction, msg, args)
  end

  defp mkdir_if_not_exists(path) do
    dir_path = Path.absname("db_logs" <> "/" <> to_string(path))
    File.mkdir_p(dir_path)
  end
end
