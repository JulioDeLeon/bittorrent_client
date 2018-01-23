defmodule PeerTest do
  use ExUnit.Case
  doctest BittorrentClient.Peer.GenServerImpl
  @peer_impl Application.get_env(:bittorrent_client, :peer_impl)
  @file_name_1 "priv/ubuntu.torrent"
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
  setup_all do
    torrent_id = "some_id"
    torrent_pid = TorrentSupervisor.start_child({torrent_id, @file_name_1})

    on_exit(fn ->
      TorrentSupervisor.terminate_child(torrent_id)
    end)
    {:ok, [torrent_id: torrent_id,
           torrent_pid: torrent_pid
          ]}
  end

  test "whereis should fail if given an invalid peer id from Peer layer" do
    assert @peer_impl.whereis("invalid_id") == :undefined
  end
end
