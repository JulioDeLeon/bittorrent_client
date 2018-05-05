# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :bittorrent_client,
  ecto_repos: [BittorrentClient.Repo]

# Configures the endpoint
config :bittorrent_client, BittorrentClientWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "veMzbQLlFgYIJHey3qSX8oNT3gSq5vHTLQ47WBf5tpeMIcW12NN1kD4ETP2OYrqU",
  render_errors: [view: BittorrentClientWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BittorrentClient.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
