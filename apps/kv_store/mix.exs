# based on https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html

defmodule KVStore.MixProject do
  use Mix.Project

  def project do
    [
      app: :kv_store,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      env: [routing_table: []],
      mod: {KVStore, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  def deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:plug, "~> 1.0"},
      {:syn, "~> 3.3"},
      {:local_cluster, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.3"},
      {:libcluster, "~> 2.2.3"},
    ]
  end
end
