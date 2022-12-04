defmodule KVStore do
  use Application
  require Logger

  @moduledoc """
  Documentation for `KVStore`.
  """

  @impl true
  def start(_type, _args) do
    # Although we don't use the supervisor name below directly,
    # it can be useful when debugging or introspecting the system.

    KVStore.Supervisor.start_link(name: KVStore.Supervisor)
  end
end
