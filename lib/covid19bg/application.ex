defmodule Covid19bg.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy,
       scheme: :http, plug: Covid19bg.API, options: [port: Application.get_env(:covid19bg, :port)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Covid19bg.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
