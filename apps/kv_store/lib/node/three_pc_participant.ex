defmodule KVStore.ThreePcParticipant do
  require Logger
  require Protocol

  def transaction(:init, node, {tx_id, queries}, %{current_tx: nil}) do
    Logger.debug("Received init call in the participant")

    # validate tx here

    state = %{ current_tx: %TxInfo{ tx_id: tx_id, status: :init, query_list: queries }}
    # write in disk for durability
    write_phase12(tx_id, state, node)
    state

  end

  def transaction(:prepare, node, tx_id, %{current_tx: %TxInfo{ tx_id: tx_id, status: :init, query_list: queries }}) do
    Logger.debug("Received prepare call in the participant")

    # validate tx here

    state = %{ current_tx: %TxInfo{ tx_id: tx_id, status: :prepare, query_list: queries }}
    # write in disk for durability
    write_phase23(tx_id, state, node)
    state

  end

  def transaction(:commit, node, _tx_id, %{current_tx: %TxInfo{ tx_id: _tx_id, status: :prepare, query_list: queries }}) do
    Logger.debug("Received commit call in the participant")
    commit(queries, node)
    %{current_tx: nil}
  end

  def transaction(:abort, _node, _tx_id, _state) do
    Logger.debug("Received abort call in the participant")

    # validate tx here
    %{current_tx: nil}
  end

  # ---- utils ----

  defp write_phase12(tx_id, state, path) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> to_string(path) <> "/" <> "tx_participant_log")
    File.write(file_path, tx_id <> ";" <> :erlang.term_to_binary(state) <> ";" <> "PHASE12" <> "\r\n", [:append])
  end

  defp write_phase23(tx_id, state, path) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> to_string(path) <> "/" <> "tx_participant_log")
    File.write(file_path, tx_id <> ";" <> :erlang.term_to_binary(state) <> ";" <> "PHASE23" <> "\r\n", [:append])
  end

  defp commit(query_list, path) do
    mkdir_if_not_exists(path)
    IO.inspect(query_list)
    Enum.each(query_list, fn {operation, args} -> KVStore.Database.perform_op(operation, to_string(path), args) end)
  end

  defp mkdir_if_not_exists(path) do
    dir_path = Path.absname("db_logs" <> "/" <> to_string(path))
    File.mkdir_p(dir_path)
  end

end
