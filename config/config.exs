# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :bittorrent_client,
  ecto_repos: [BittorrentClient.Repo],
  upload_check: false,
  server_name: "GenericName",
  file_destination: "priv/output/",
  peer_id: "-ET0001-aaaaaaaaaaaa",
  compact: 1,
  port: 36_562,
  no_peer_id: 0,
  ip: "127.0.0.1",
  numwant: 40,
  allowedconnections: 2,
  key: "",
  trackerid: "",
  server_impl: BittorrentClient.Server.GenServerImpl,
  torrent_impl: BittorrentClient.Torrent.GenServerImpl,
  peer_impl: BittorrentClient.Peer.GenServerImpl,
  tcp_conn_impl: BittorrentClient.TCPConn.GenTCPImpl,
  http_handle_impl: BittorrentClient.HTTPHandle.HTTPoisonImpl,
  config_cache_impl: BittorrentClient.Cache.ETSImpl,
  config_cache_name: :config_cache,
  config_cache_opts: [:set, :protected],
  torrent_cache_impl: BittorrentClient.Cache.MnesiaImpl,
  torrent_cache_name: :torrent_cache,
  # 16KB
  default_block_size: 16384,
  default_tcp_buffer_size: 32768,
  default_tcp_recv_buffer_size: 32768

# Configures the endpoint
config :bittorrent_client, BittorrentClientWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base:
    "veMzbQLlFgYIJHey3qSX8oNT3gSq5vHTLQ47WBf5tpeMIcW12NN1kD4ETP2OYrqU",
  render_errors: [view: BittorrentClientWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BittorrentClient.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time [$level] [$metadata] $message\n",
  metadata: [:module, :function, :line, :pid],
  colors: [warn: :yellow, error: :red],
  level: :debug

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
