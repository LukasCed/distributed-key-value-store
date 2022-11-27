defmodule KVServer.ThreePcProtocol do

  def handle_transaction(tx_id) do
    acks = broadcast(:init, :none) # retransmit on timeout?
    if Enum.all?(acks, fn x -> x == :agree end) do
      write_log(tx_id, "phase12")
      acks = broadcast(:prepare, :none)  # retransmit on timeout?
      if Enum.all?(acks, fn x -> x == :agree end) do
        write_log(tx_id, "phase23")
        acks = broadcast(:commit, :none)  # retransmit on timeout?
        if Enum.all?(acks, fn x -> x == :agree end) do
          write_log(tx_id, "complete")
          :commit_success
        end
      end
    end

    broadcast(:abort, :none)  # retransmit on timeout?
    write_log(tx_id, "complete")
    :commit_failure
  end

  def write_log(tx_id, msg) do
    File.write("tx_manager_log", tx_id <> ";" <> msg <> "\r\n", [:append])
  end

  def broadcast(msg, tx_id) do
    KVStore.Router.route_all(KVStore.Registry, msg, [tx_id])
  end

end
