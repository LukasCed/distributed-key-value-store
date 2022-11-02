defmodule KVServer.Command do
  require Logger

  @doc """
  Runs the given command.
  """
  def run(command)

  def run({:create, tx, table}) do
    KVServer.TxManager.manage_transaction(tx, fn txid ->
      KVStore.Router.route_all(KVStore.Registry, :create, [table, {tx, txid}])
    end)

    {:ok, "OK: Table created\r\n"}
  end

  def run({:put, tx, table, key, value}) do
    KVServer.TxManager.manage_transaction(tx, fn txid ->
      # route to the node according to the key
      KVStore.Router.route(key, KVStore.Registry, :put, [table, key, value, {tx, txid}])
    end)

    {:ok, "OK: Value stored\r\n"}
  end

  def run({:get, tx, table, key}) do
    case KVServer.TxManager.manage_transaction(tx, fn txid ->
           KVStore.Router.route(key, KVStore.Registry, :get, [table, key, {tx, txid}])
         end) do
      {:ok, value} -> {:ok, "OK: #{value}\r\n"}
      {:error, _} -> {:ok, "ERROR: value in table #{table} with the key #{key} not found\r\n"}
    end
  end

  def run({:delete, tx, table, key}) do
    KVServer.TxManager.manage_transaction(tx, fn txid ->
      KVStore.Router.route(key, KVStore.Registry, :delete, [table, key, {tx, txid}])
    end)

    {:ok, "OK: Value deleted\r\n"}
  end

  # curr state vs prev state
  def run({:transaction, :no_transaction}) do
    Logger.debug("Started a transaction")
    {:ok, txid} = KVServer.TxManager.start_transaction()
    {:ok, "OK: transaction #{inspect(txid)} started\r\n"}
  end

  # curr state vs prev state
  def run({:transaction, :transaction}) do
    raise "Cannot start a transaction in process while another transaction is ongoing"
  end

  # curr state vs prev state
  def run({:end_transaction, :transaction}) do
    Logger.debug("Ending a transaction")

    case KVServer.TxManager.end_transaction() do
      {:ok, txid} ->
        {:ok, "OK: transaction #{inspect(txid)} ended\r\n"}

      {:prepare_fail, txid} ->
        {:ok, "ERROR: Could not get all nodes to agree in tx #{inspect(txid)}\r\n"}

      {:commit_fail, txid} ->
        {:ok, "ERROR: Could not get all nodes to commit in tx #{inspect(txid)}\r\n"}
    end
  end

  # curr state vs prev state
  def run({:end_transaction, :no_transaction}) do
    raise "Cannot end a transaction that is not started"
  end

  # defp lookup_table(table, callback) do
  #   case KVStore.Router.route_all(table, :not_important, KVStore.Registry, :lookup, [KVStore.Registry, table, key]) do
  #     {:ok, pid} -> callback.(pid)
  #     :error -> {:error, :not_found}
  #     Logger.error("Pid #{inspect(pid)}")
  #   end
  # end

  # defp lookup(table, callback) do
  #   case KVStore.Router.route(table, :not_important, KVStore.Registry, :lookup, [KVStore.Registry, table, key]) do
  #     {:ok, pid} -> callback.(pid)
  #     :error -> {:error, :not_found}
  #   end
  # end

  @doc ~S"""
    Parses the given `line` into a command.

    ## Examples

        iex> KVStore.Command.parse "CREATE shopping\r\n"
        {:ok, {:create, "shopping"}}

        iex> KVStore.Command.parse "CREATE  shopping  \r\n"
        {:ok, {:create, "shopping"}}

        iex> KVStore.Command.parse "PUT shopping milk 1\r\n"
        {:ok, {:put, "shopping", "milk", "1"}}

        iex> KVStore.Command.parse "GET shopping milk\r\n"
        {:ok, {:get, "shopping", "milk"}}

        iex> KVStore.Command.parse "DELETE shopping eggs\r\n"
        {:ok, {:delete, "shopping", "eggs"}}

    Unknown commands or commands with the wrong number of
    arguments return an error:

        iex> KVStore.Command.parse "UNKNOWN shopping eggs\r\n"
        {:error, :unknown_command}

        iex> KVStore.Command.parse "GET shopping\r\n"
        {:error, :unknown_command}

  """
  def parse(line) do
    # check for ongoing transaction
    tx = get_current_transaction()

    case String.split(String.upcase(line)) do
      ["CREATE", table] -> {:ok, {:create, tx, table}}
      ["GET", table, key] -> {:ok, {:get, tx, table, key}}
      ["PUT", table, key, value] -> {:ok, {:put, tx, table, key, value}}
      ["DELETE", table, key] -> {:ok, {:delete, tx, table, key}}
      ["TRANSACTION"] -> {:ok, {:transaction, tx}}
      ["END"] -> {:ok, {:end_transaction, tx}}
      _ -> {:error, :unknown_command}
    end
  end

  defp get_current_transaction() do
    case KVServer.TxManager.get_txid() do
      {:ok, nil} -> :no_transaction
      {:ok, _} -> :transaction
      _ -> :no_transaction
    end
  end
end
