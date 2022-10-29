defmodule FA.Bucket do
  use Agent, restart: :temporary

  @doc """
  Starts a new bucket
  """
  def start_link(_opts) do
    Agent.start_link fn -> %{} end
  end

  def put(agent, key, item) do
    Agent.update(agent, &Map.put(&1, key, item))
  end

  def get(agent, key) do
    Agent.get(agent, &Map.get(&1, key))
  end

  def delete(agent, key) do
    Agent.get_and_update(agent, &Map.pop(&1, key))
  end

  # def sync(agent, key) do
  #   members = for {pid, _} <- :syn.members(:first_assignment, :bucket), pid != self, do: pid
  # end
end
