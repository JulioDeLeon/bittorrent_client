defmodule TorrentTest do
  use ExUnit.Case
  doctest BittorrentClient.Server.GenServerImpl
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @file_name_1 "priv/ubuntu.torrent"
  @file_name_2 "priv/arch.torrent"
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor

  setup do
    on_exit(fn ->
      _ret = @server_impl.delete_all_torrents(@server_name)
    end)
  end

  test "whereis should return a valid pid from Torrent layer", context do
    {add_status, data} = @server_impl.add_new_torrent(@server_name, @file_name_1)
    assert add_status == :ok
    torrent_pid = Map.get(data, "torrent id")

    assert is_pid(@torrent_impl.whereis(torrent_pid))
  end

  test "whereis should return undefined when given invalid id from Torrent layer", context do
    assert @torrent_impl.whereis("fake id") == :undefined
  end
end
