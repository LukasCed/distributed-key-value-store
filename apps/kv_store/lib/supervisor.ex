defmodule KVStore.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: KVStore.TableSupervisor, strategy: :one_for_one},
      {KVStore.Registry, name: KVStore.Registry}
      # {Task.Supervisor, name: KVStore.RouterTasks}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
