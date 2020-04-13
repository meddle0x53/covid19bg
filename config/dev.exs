import Config

config :covid19bg,
  port: 5554,
  store:
    {Covid19bg.Store.Postgres,
     [
       hostname: "localhost",
       password: "covid19bg",
       username: "covid19bg",
       database: "covid19bg",
       updaters: [
         [update_interval: 160_000, name: :covid19bg_bg_updater],
         [
           update_interval: 130_000,
           name: :covid19bg_world_updater,
           sources: [Covid19bg.Source.World]
         ]
       ]
     ]}
