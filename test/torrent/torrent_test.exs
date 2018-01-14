defmodule TorrentTest do
  use ExUnit.Case
  doctest BittorrentClient.Server.GenServerImpl

  test "create initial date for torrent process" do
    id = "some_id"
    file = "./priv/ubuntu.torrent"

    bento_metainfo =
      file
      |> File.read!()
      |> Bento.torrent!()

    %TorrentData{
      id: id,
      pid: self(),
      file: file,
      status: :initial,
      info_hash: hash,
      peer_id: Application.fetch_env!(:bittorrent_client, :peer_id),
      port: Application.fetch_env!(:bittorrent_client, :port),
      uploaded: 0,
      downloaded: 0,
      left: metadata.info.length,
      compact: Application.fetch_env!(:bittorrent_client, :compact),
      no_peer_id: Application.fetch_env!(:bittorrent_client, :no_peer_id),
      ip: Application.fetch_env!(:bittorrent_client, :ip),
      numwant: Application.fetch_env!(:bittorrent_client, :numwant),
      key: Application.fetch_env!(:bittorrent_client, :key),
      trackerid: Application.fetch_env!(:bittorrent_client, :trackerid),
      tracker_info: %TrackerInfo{},
      pieces: %{},
      next_piece_index: 0,
      connected_peers: []
    }
  end
end
