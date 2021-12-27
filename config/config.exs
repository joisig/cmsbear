# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :cmsbear,
  ecto_repos: [Cmsbear.Repo]

# Configures the endpoint
config :cmsbear, CmsbearWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: CmsbearWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Cmsbear.PubSub,
  live_view: [signing_salt: "GV6frsRe"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# OpenID Connect configuration
config :cmsbear, :openid_connect_providers,
  google: [
    discovery_document_uri: "https://accounts.google.com/.well-known/openid-configuration",
    client_id: "503235626927-ti2snvjb37vtlevo8srsinaf8m24uvrt.apps.googleusercontent.com",
    client_secret: "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",
    redirect_uri: "https://joitestwww.eu.ngrok.io/auth/oidc/callback",
    response_type: "code",
    scope: "openid email profile"
  ]

config :openid_connect, :initialization_delay_ms, 3000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
