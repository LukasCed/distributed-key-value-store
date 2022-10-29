defmodule FaUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        foo: [
          version: "0.0.1",
          applications: [fa_server: :permanent, first_assignment: :permanent],
          cookie: "weknoweachother"
        ],
        bar: [
          version: "0.0.1",
          applications: [first_assignment: :permanent],
          cookie: "weknoweachother"
        ]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
