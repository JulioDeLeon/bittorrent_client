use Mix.Config

config :bittorrent_client,
  server_name: "GenericName",
  peer_id: "-ET0001-aaaaaaaaaaaa",
  compact: 1,
  port: 36562,
  no_peer_id: 0,
  ip: "127.0.0.1",
  numwant: 80,
  key: "",
  server_impl: BittorrentClient.Server.GenServerImpl,
  torrent_impl: BittorrentClient.Torrent.GenServerImpl,
  peer_impl: BittorrentClient.Peer.GenServerImpl,
  tcp_conn_impl: BittorrentClient.TCPConn.InMemoryImpl,
  http_handle_impl: BittorrentClient.HTTPHandle.InMemoryImpl,
  upload_check: false
