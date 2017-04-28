defmodule BittorrentClient do
  @behaviour Application
  @moduledoc """
  BittorrentClient is a torrent client written in Elixir. This module is the entry point of the application
  """
  alias BittorrentClient.ServerSupervisor, as: ServerSupervisor
  alias BittorrentClient.WebSupervisor, as: WebSupervisor
  alias BittorrentClient.TorrentSupervisor, as: TorrentSupervisor

  def start(_type, _args) do
    ServerSupervisor.start_link()
    WebSupervisor.start_link()
	TorrentSupervisor.start_link()
  end

  def stop(_) do
    # ServerSupervisor.terminate("")
    # WebSupervisor.terminate()
    # Database.terminate()
    # may need to unload the application also
    Application.stop(self())
  end
end
