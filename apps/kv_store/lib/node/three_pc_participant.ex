defmodule KVStore.ThreePcParticipant do
  require Logger
  require Protocol

  def transaction(:init, node, {tx_id, queries}, %{current_tx: nil}) do
    Logger.debug("Received init call in the participant")

    # validate tx here

    state = %{current_tx: %TxInfo{tx_id: tx_id, status: :init, query_list: queries}}
    # write in disk for durability
    write_log(tx_id, state, node, "PHASE12")
    state
  end

  def transaction(:prepare, node, tx_id, %{
        current_tx: %TxInfo{tx_id: tx_id, status: :init, query_list: queries}
      }) do
    Logger.debug("Received prepare call in the participant")

    # validate tx here

    state = %{current_tx: %TxInfo{tx_id: tx_id, status: :prepare, query_list: queries}}
    # write in disk for durability
    write_log(tx_id, state, node, "PHASE23")
    state
  end

  # todo:add a timeout - after phase23 he knows he can commit even if he loses the :commit msg?
  def transaction(:commit, node, _tx_id, %{
        current_tx: %TxInfo{tx_id: _tx_id, status: :prepare, query_list: queries}
      }) do
    Logger.debug("Received commit call in the participant")
    commit(queries, node)
    # cleanup
    delete_log(node)
    %{current_tx: nil}
  end

  def transaction(:abort, node, _tx_id, _state) do
    Logger.debug("Received abort call in the participant")

    # cleanup
    delete_log(node)
    %{current_tx: nil}
  end

  # ---- utils ----

  def read_log(path) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> to_string(path) <> "/" <> "tx_participant_log")
    Logger.debug("Loading state from #{inspect(file_path)} in the participant node")

    if not File.exists?(file_path) do
      %{current_tx: nil}
    else
      {:ok, logs} = File.read(file_path)
      contents = List.last(logs |> String.split("\r\n", trim: true))
      [_tx_id, binary_term, _msg] = contents |> String.split(";", trim: true)
      :erlang.binary_to_term(binary_term)
    end
  end

  def commit(query_list, path) do
    mkdir_if_not_exists(path)
    IO.inspect(query_list)

    Enum.each(query_list, fn {operation, args} ->
      KVStore.Database.perform_op(operation, to_string(path), args)
    end)
  end

  defp write_log(tx_id, state, path, msg) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> to_string(path) <> "/" <> "tx_participant_log")

    File.write(file_path, tx_id <> ";" <> :erlang.term_to_binary(state) <> ";" <> msg <> "\r\n", [
      :append
    ])
  end

  defp delete_log(path) do
    file_path = Path.absname("db_logs" <> "/" <> to_string(path) <> "/" <> "tx_participant_log")
    File.rm(file_path)
  end

  defp mkdir_if_not_exists(path) do
    dir_path = Path.absname("db_logs" <> "/" <> to_string(path))
    File.mkdir_p(dir_path)
  end
end
