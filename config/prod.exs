import Config

config :logger,
  level: :info,
  format: "[$level] $message\n",
  backends: [
    {LoggerFileBackend, :error_log},
    {LoggerFileBackend, :warn_log},
    {LoggerFileBackend, :info_log},
    :console
  ]

config :logger, :error_log, path: "log/error.log", level: :error
config :logger, :warn_log, path: "log/warn.log", level: :warn
config :logger, :info_log, path: "log/info.log", level: :info
