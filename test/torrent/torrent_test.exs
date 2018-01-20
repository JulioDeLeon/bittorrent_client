defmodule TorrentTest do
  use ExUnit.Case
  doctest BittorrentClient.Server.GenServerImpl
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
end
