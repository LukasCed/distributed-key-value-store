defmodule KVServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    IO.puts(:stdio, Application.get_env(:kv_server, :port) )
    port = String.to_integer(Application.get_env(:kv_server, :port) || System.get_env("PORT") || "4040")

    children = [
      # Starts a worker by calling: KVStore.Worker.start_link(arg)
      # {KVServer.Worker, arg}
      {Task.Supervisor, name: KVServer.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> KVServer.accept(port) end}, restart: :permanent),
      {KVServer.TxManager, name: KVServer.TxManager}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KVServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
