use Mix.Config

config :libcluster,
  topologies: [
    exploring_elixir: [
      strategy: Cluster.Strategy.Gossip,
      #config: {},
      connect: {KVServer.AutoCluster, :connect_node, []},
      disconnect: {KVServer.AutoCluster, :disconnect_node, []},
      #list_nodes: {:erlang, :nodes, [:connected]},
      #child_spec: [restart: :transient]
    ]
  ]
