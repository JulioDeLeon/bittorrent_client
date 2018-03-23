# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :bittorrent_client, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:bittorrent_client, :key)
#
# Or configure a 3rd-party app:
#
config :logger, :console,
  format: "$time [$level] [$metadata] $message\n",
  metadata: [:module, :function, :line, :pid],
  colors: [warn: :yellow, error: :red],
  level: :debug

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
config :bittorrent_client,
  upload_check: false,
  server_name: "GenericName",
  peer_id: "-ET0001-aaaaaaaaaaaa",
  compact: 1,
  port: 36_562,
  no_peer_id: 0,
  ip: "127.0.0.1",
  numwant: 1,
  key: "",
  trackerid: "",
  server_impl: BittorrentClient.Server.GenServerImpl,
  torrent_impl: BittorrentClient.Torrent.GenServerImpl,
  peer_impl: BittorrentClient.Peer.GenServerImpl,
  tcp_conn_impl: BittorrentClient.TCPConn.GenTCPImpl,
  http_handle_impl: BittorrentClient.HTTPHandle.HTTPoisonImpl

import_config "#{Mix.env()}.exs"
