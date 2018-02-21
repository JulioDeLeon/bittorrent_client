use Mix.Config

config :bittorrent_client,
  server_impl: BittorrentClient.Server.GenServerImpl,
  torrent_impl: BittorrentClient.Torrent.GenServerImpl,
  peer_impl: BittorrentClient.Peer.GenServerImpl,
  tcp_conn_impl: BittorrentClient.TCPConn.InMemoryImpl,
  http_handle_impl: BittorrentClient.HTTPHandle.InMemoryImpl
