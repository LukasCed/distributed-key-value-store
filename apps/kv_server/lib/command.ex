defmodule KVServer.Command do
  require Logger

  @doc """
  Runs the given command.
  """
  def run(command)

  def run({:create, table}) do
    # case KVStore.Router.route_all(table, :none, KVStore.Registry, :create, [KVStore.Registry, table]) do
    #   pid when is_pid(pid) -> {:ok, "OK\r\n"}
    #   _ -> {:error, "FAILED TO CREATE TABLE"}
    #   Logger.error("Failed to create table " + table)
    #   Logger.error("Pid #{inspect(pid)}")
    # end

    KVStore.Router.route_all(KVStore.Registry, :create, [table])
    {:ok, "OK: Table created\r\n"}
  end

  def run({:put, table, key, value}) do
    # lookup(table, fn pid ->
    #   KVStore.Table.put(pid, key, value)
    #   {:ok, "OK\r\n"}
    # end)

    # ensure there is such a table (using the lookup) should return from all
    # @todo fix
    # KVStore.Router.route_all(KVStore.Registry, :create, [KVStore.Registry, table])

    # route to the node according to the key

    KVStore.Router.route(key, KVStore.Registry, :put, [table, key, value])
    {:ok, "OK: Value stored\r\n"}
  end

  def run({:get, table, key}) do
    # lookup(table, fn pid ->
    #   value = KVStore.Table.get(pid, key)
    #   {:ok, "#{value}\r\nOK\r\n"}
    # end)

    case KVStore.Router.route(key, KVStore.Registry, :get, [table, key]) do
      {:ok, value} ->  {:ok, "OK: #{value}\r\n"}
      {:error, value} -> {:ok, "ERROR: value in table #{table} with the key #{key} not found\r\n"}
    end
  end

  def run({:delete, table, key}) do
    # lookup(table, fn pid ->
    #   KVStore.Table.delete(pid, key)
    #   {:ok, "OK\r\n"}
    # end)

    KVStore.Router.route(key, KVStore.Registry, :delete, [table, key])
    {:ok, "OK: Value deleted\r\n"}
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
    case String.split(String.upcase(line)) do
      ["CREATE", table] -> {:ok, {:create, table}}
      ["GET", table, key] -> {:ok, {:get, table, key}}
      ["PUT", table, key, value] -> {:ok, {:put, table, key, value}}
      ["DELETE", table, key] -> {:ok, {:delete, table, key}}
      _ -> {:error, :unknown_command}
    end
  end

end
