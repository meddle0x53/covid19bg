import Config

config :covid19bg,
  port: System.fetch_env!("COVID_19_BG_PORT") |> String.to_integer(),
  store:
    {Covid19bg.Store.Postgres,
     [
       hostname: "localhost",
       password: System.fetch_env!("COVID_19_DB_PASSWORD"),
       username: "covid19bg",
       database: "covid19bg",
       pool_size: 5
     ]}
