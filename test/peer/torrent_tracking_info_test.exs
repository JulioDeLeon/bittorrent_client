defmodule BittorrentClient.Peer.TorrentTrackingInfo.Test do
  use ExUnit.Case
  doctest BittorrentClient.Peer.TorrentTrackingInfo
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @file_name_1 "priv/ubuntu.torrent"
  alias BittorrentClient.Peer.TorrentTrackingInfo, as: TorrentTrackingInfo

  setup_all do
    case @server_impl.add_new_torrent(@server_name, @file_name_1) do
      {:ok, resp} ->
        {:ok, [torrent_id: Map.get(resp, "torrent id")]}
      _ ->
        {:error, "could not add new torrent"}
    end
  end

  setup do
    on_exit(fn ->
      _ret = @server_impl.delete_all_torrents(@server_name)
    end)
  end

  test "Assert known pieces is empty on creation", context do
    ttinfo = %TorrentTrackingInfo{
      id: context.torrent_id,
      piece_table: %{}
    }

    assert length(TorrentTrackingInfo.get_known_pieces(ttinfo)) == 0
  end
end