defmodule BittorrentClient do
  @behaviour Application
  @moduledoc """
  BittorrentClient is a torrent client written in Elixir. This module is the entry point of the application
  """
  def start(_type, _args) do
    BittorrentClient.Supervisor.start_link()
  end

  def stop(_) do
    Application.stop(__MODULE__)
  end

  def setup_dev_env do
    :observer.start()
    :debugger.start()
    :int.ni(Application.get_env(:bittorrent_client, :server_impl))
    :int.ni(Application.get_env(:bittorrent_client, :torrent_impl))
    :int.ni(Application.get_env(:bittorrent_client, :peer_impl))
    :int.ni(Application.get_env(:bittorrent_client, :tcp_conn_impl))
    :int.ni(Application.get_env(:bittorrent_client, :http_handle_impl))
  end
end
