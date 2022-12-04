defmodule KVServer.Command do
  require Logger

  def parse(line) do
    # check for ongoing transaction
    case String.split(String.upcase(line)) do
      ["CREATE", table] -> {:ok, {:create, table}}
      ["GET", table, key] -> {:ok, {:get, {table, key}}}
      ["PUT", table, key, value] -> {:ok, {:put, {table, key, value}}}
      ["DELETE", table, key] -> {:ok, {:delete, {table, key}}}
      ["TRANSACTION"] -> {:ok, {:start_transaction}}
      ["END"] -> {:ok, {:end_transaction}}
      _ -> {:error, :unknown_command}
    end
  end

end
