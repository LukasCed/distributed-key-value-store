defmodule FAServer.Command do

  @doc """
  Runs the given command.
  """
  def run(command)

  def run({:create, bucket}) do
    case FA.Router.route(bucket, FA.Registry, :create, [FA.Registry, bucket]) do
      pid when is_pid(pid) -> {:ok, "OK\r\n"}
      _ -> {:error, "FAILED TO CREATE BUCKET"}
    end
  end


  def run({:get, bucket, key}) do
    lookup(bucket, fn pid ->
      value = FA.Bucket.get(pid, key)
      {:ok, "#{value}\r\nOK\r\n"}
    end)
  end

  def run({:put, bucket, key, value}) do
    lookup(bucket, fn pid ->
      FA.Bucket.put(pid, key, value)
      {:ok, "OK\r\n"}
    end)
  end

  def run({:delete, bucket, key}) do
    lookup(bucket, fn pid ->
      FA.Bucket.delete(pid, key)
      {:ok, "OK\r\n"}
    end)
  end

  # def run({:sync, bucket}) do

  # end

  defp lookup(bucket, callback) do
    case FA.Router.route(bucket, FA.Registry, :lookup, [FA.Registry, bucket]) do
      {:ok, pid} -> callback.(pid)
      :error -> {:error, :not_found}
    end
  end


  @doc ~S"""
  Parses the given `line` into a command.

  ## Examples

      iex> FAServer.Command.parse "CREATE shopping\r\n"
      {:ok, {:create, "shopping"}}

      iex> FAServer.Command.parse "CREATE  shopping  \r\n"
      {:ok, {:create, "shopping"}}

      iex> FAServer.Command.parse "PUT shopping milk 1\r\n"
      {:ok, {:put, "shopping", "milk", "1"}}

      iex> FAServer.Command.parse "GET shopping milk\r\n"
      {:ok, {:get, "shopping", "milk"}}

      iex> FAServer.Command.parse "DELETE shopping eggs\r\n"
      {:ok, {:delete, "shopping", "eggs"}}

  Unknown commands or commands with the wrong number of
  arguments return an error:

      iex> FAServer.Command.parse "UNKNOWN shopping eggs\r\n"
      {:error, :unknown_command}

      iex> FAServer.Command.parse "GET shopping\r\n"
      {:error, :unknown_command}

"""
  def parse(line) do
    case String.split(line) do
      ["CREATE", bucket] -> {:ok, {:create, bucket}}
      ["GET", bucket, key] -> {:ok, {:get, bucket, key}}
      ["PUT", bucket, key, value] -> {:ok, {:put, bucket, key, value}}
      ["DELETE", bucket, key] -> {:ok, {:delete, bucket, key}}
      _ -> {:error, :unknown_command}
    end
  end


end
