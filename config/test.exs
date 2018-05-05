use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bittorrent_client, BittorrentClientWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :bittorrent_client, BittorrentClient.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "bittorrent_client_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox


config :bittorrent_client,
  server_impl: BittorrentClient.Server.GenServerImpl,
  torrent_impl: BittorrentClient.Torrent.GenServerImpl,
  peer_impl: BittorrentClient.Peer.GenServerImpl,
  tcp_conn_impl: BittorrentClient.TCPConn.InMemoryImpl,
  http_handle_impl: BittorrentClient.HTTPHandle.InMemoryImpl
