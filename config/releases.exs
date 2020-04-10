import Config

config :covid19bg, :port, System.fetch_env!("COVID_19_BG_PORT") |> String.to_integer()
