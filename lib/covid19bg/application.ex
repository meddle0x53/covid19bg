defmodule Covid19bg.Application do
  @moduledoc false

  use Application

  def start(_type, args) do
    children = [
      {Task.Supervisor, [name: :tasks_supervisor]},
      {Plug.Cowboy,
       scheme: :http, plug: Covid19bg.API, options: [port: Application.get_env(:covid19bg, :port)]}
    ]

    opts = [strategy: :one_for_one, name: Covid19bg.Supervisor]
    sup = Supervisor.start_link(children, opts)

    :ok = Covid19bg.initialize(args)

    sup
  end
end
