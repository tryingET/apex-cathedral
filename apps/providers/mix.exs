defmodule Providers.MixProject do
  use Mix.Project

  def project do
    [
      app: :providers,
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
      mod: {Apex.Providers.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:apex, in_umbrella: true},
      {:resources, in_umbrella: true}
    ]
  end
end
