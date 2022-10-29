defmodule FA.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: FA.BucketSupervisor, strategy: :one_for_one},
      {FA.Registry, name: FA.Registry},
      {Task.Supervisor, name: FA.RouterTasks}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

end
