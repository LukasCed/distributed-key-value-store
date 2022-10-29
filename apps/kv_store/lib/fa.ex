defmodule FA do
  use Application
  @moduledoc """
  Documentation for `FA`.
  """

  @impl true
  def start(_type, _args) do
    # Although we don't use the supervisor name below directly,
    # it can be useful when debugging or introspecting the system.

    # :ok = :syn.add_node_to_scopes([:first_assignment])

    FA.Supervisor.start_link(name: FA.Supervisor)
  end
end
