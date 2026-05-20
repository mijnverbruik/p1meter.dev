# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :live_meter,
  generators: [timestamp_type: :utc_datetime]

config :live_meter, LiveMeter.TCPServer,
  port: 8080,
  max_clients: 100,
  max_clients_per_ip: 5,
  accept_rate_limit: {1, 20},
  listen_backlog: 128

config :live_meter, LiveMeter.SmartMeter, interval: 1_000

config :makeup_syntect, register_for_languages: ["javascript"]

# Configure the endpoint
config :live_meter, LiveMeterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LiveMeterWeb.ErrorHTML, json: LiveMeterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LiveMeter.PubSub,
  live_view: [signing_salt: "H3JVDIxY"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  live_meter: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  live_meter: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use native library for JSON parsing in Phoenix
config :phoenix, :json_library, JSON

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
