defmodule KVStore.Table do
  use Agent, restart: :temporary

  @doc """
  Starts a new table
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end

  def put(agent, key, item) do
    Agent.update(agent, &Map.put(&1, key, item))
  end

  def get(agent, key) do
    Agent.get(agent, &Map.get(&1, key))
  end

  def get_all(agent) do
    Agent.get(agent, fn map -> map end)
  end

  def delete(agent, key) do
    Agent.get_and_update(agent, &Map.pop(&1, key))
  end
end
