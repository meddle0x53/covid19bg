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
         [update_interval: 60000, name: :covid19bg_bg_updater]
       ]
     ]}
