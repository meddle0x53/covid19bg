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
       pool_size: 5,
       updaters: [
         [update_interval: 600_000, name: :covid19bg_bg_updater],
         [
           update_interval: 300_000,
           name: :covid19bg_world_updater,
           sources: [Covid19bg.Source.World]
         ]
       ]
     ]}
