defmodule KVStore.Database do
  require Logger

  def perform_op(:create, path, {table}) do
    dir_path = Path.absname("db_logs" <> "/" <> path <> "/" <> table)
    File.mkdir_p(dir_path)
    {:ok, table}
  end

  def perform_op(:put, path, {table, key, value}) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> path <> "/" <> table <> "/" <> key)

    if not File.exists?(file_path) do
      File.touch!(file_path)
    end

    File.write!(file_path, value)
    {:ok, value}
  end

  def perform_op(:get, path, {table, key}) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> path <> "/" <> table <> "/" <> key)
    Logger.debug("Looking in #{inspect(file_path)}")
    File.read(file_path)
  end

  def perform_op(:delete, path, {table, key}) do
    mkdir_if_not_exists(path)
    file_path = Path.absname("db_logs" <> "/" <> path <> "/" <> table <> "/" <> key)
    File.rm!(file_path)
    {:ok, key}
  end

  defp mkdir_if_not_exists(path) do
    dir_path = Path.absname("db_logs" <> "/" <> to_string(path))
    File.mkdir_p(dir_path)
  end
end
