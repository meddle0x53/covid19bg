defmodule Covid19bg.MixProject do
  use Mix.Project

  def project do
    [
      app: :covid19bg,
      version: "0.2.1",
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
      {:mint, "~> 1.0"},
      {:number, "~> 1.0.1"}
    ]
  end
end
