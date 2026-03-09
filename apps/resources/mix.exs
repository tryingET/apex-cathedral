defmodule Resources.MixProject do
  use Mix.Project

  def project do
    [
      app: :resources,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Apex.Resources.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:apex, in_umbrella: true},
      {:audit, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:exqlite, "~> 0.8"}
    ]
  end
end
