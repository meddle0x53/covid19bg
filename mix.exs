defmodule Covid19bg.MixProject do
  use Mix.Project

  @version "0.3.1"

  def project do
    [
      app: :covid19bg,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Covid19bg.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.0"},
      {:castore, "~> 0.1.0"},
      {:mojito, "~> 0.6.1"},
      {:number, "~> 1.0.1"},
      {:postgrex, "~> 0.15.3"},
      {:countriex, "~> 0.4"}
    ]
  end
end
